package polymod.hscript._internal;

import Type as HaxeType;
import polymod.hscript._internal.Expr;
import polymod.hscript._internal.TypedExpr;

@:nullSafety
class Typer
{
  var locals:Array<{name:String, type:Type}>;
  var errors:Array<TypedExprError>;

  public function new()
  {
    this.locals = [];
    this.errors = [];
  }

  public function typeExpr(expr:Expr):TypedExpr
  {
    switch (Tools.expr(expr))
    {
      case EConst(c):
        switch (c)
        {
          case CInt(v):
            return makeExpr(TEConst(TCInt(v)), TInt, expr);

          case CFloat(f):
            return makeExpr(TEConst(TCFloat(f)), TFloat, expr);

          case CString(s, interpolated):
            return makeExpr(TEConst(TCString(s, interpolated)), TClass(String), expr);
        }

      case EIdent(v):
        switch (v)
        {
          case 'true':
            return makeExpr(TEConst(TCBool(true)), TBool, expr);

          case 'false':
            return makeExpr(TEConst(TCBool(false)), TBool, expr);

          case 'null':
            return makeExpr(TEConst(TCNull), TNull, expr);

          default:
            var local = getLocal(v);
            if (local == null)
            {
              return makeExprError('Could resolve identifier $v', TEIdent(v), expr);
            }
            return makeExpr(TEIdent(local.name), local.type, expr);
        }

      case EVar(n, t, e):
        var type = t != null ? resolveType(t) : null;
        var typedExpr = e != null ? typeExpr(e) : null;

        if (type != null && typedExpr != null && !isDynamic(type))
        {
          if (!isEqual(type, typedExpr.t))
          {
            return makeExprError('Cannot assign ${typedExpr.t} to ${type}', TEVar(n, t, typedExpr), expr);
          }
        }

        return makeExpr(TEVar(n, t, typedExpr), TVoid, expr);

      case EFinal(n, t, e):
        var type = t != null ? resolveType(t) : null;
        var typedExpr = e != null ? typeExpr(e) : null;

        if (type != null && typedExpr != null && !isDynamic(type))
        {
          if (!isEqual(type, typedExpr.t))
          {
            return makeExprError('Cannot assign ${typedExpr.t} to ${type}', TEFinal(n, t, typedExpr), expr);
          }
        }

        return makeExpr(TEFinal(n, t, typedExpr), TVoid, expr);

      case EParent(e):
        var typedExpr = typeExpr(e);
        return makeExpr(TEParent(typedExpr), typedExpr.t, expr);

      case EBlock(es):
        var typedExprs = [];
        for (e in es)
        {
          var typedExpr = typeExpr(e);
          typedExprs.push(typedExpr);
        }

        var type = typedExprs.length > 0 ? typedExprs[typedExprs.length - 1].t : TDynamic;

        return makeExpr(TEBlock(typedExprs), type, expr);

      case EField(e, f):
        var typedExpr = typeExpr(e);
        var type = TDynamic;
        return makeExpr(TEField(typedExpr, f), type, expr);

      case EBinop(op, e1, e2):
        var typedExpr1 = typeExpr(e1);
        var typedExpr2 = typeExpr(e2);

        var type;
        if (!isDynamic(typedExpr1.t) && !isDynamic(typedExpr2.t))
        {
          if (!isEqual(typedExpr1.t, typedExpr2.t))
          {
            if (isNumber(typedExpr1.t) && isNumber(typedExpr2.t))
            {
              type = TFloat;
            }
            else
            {
              return makeExprError('Cannot use "$op" with ${typedExpr1.t} and ${typedExpr2.t}', TEBinop(op, typedExpr1, typedExpr2), expr);
            }
          }
          else
          {
            type = typedExpr1.t;
          }
        }
        else if (isDynamic(typedExpr1.t))
        {
          type = typedExpr2.t;
        }
        else
        {
          type = typedExpr1.t;
        }

        return makeExpr(TEBinop(op, typedExpr1, typedExpr2), type, expr);

      case EUnop(op, prefix, e):
        var typedExpr = typeExpr(e);
        return makeExpr(TEUnop(op, prefix, typedExpr), typedExpr.t, expr);

      case ECall(e, params):
        var typedExpr = typeExpr(e);

        var typedParams = [];
        for (p in params)
        {
          var typedParam = typeExpr(p);
          typedParams.push(typedParam);
        }

        var type = TDynamic;
        return makeExpr(TECall(typedExpr, typedParams), type, expr);

      case EIf(cond, e1, e2):
        var typedCond = typeExpr(cond);
        var typedExpr1 = typeExpr(e1);
        var typedExpr2 = e2 != null ? typeExpr(e2) : null;

        if (!isBool(typedCond.t))
        {
          return makeExprError('Condition must be a Bool', TEIf(typedCond, typedExpr1, typedExpr2), expr);
        }

        var type = TDynamic;
        return makeExpr(TEIf(typedCond, typedExpr1, typedExpr2), type, expr);

      case EWhile(cond, e):
        var typedCond = typeExpr(cond);
        var typedExpr = typeExpr(e);

        if (!isBool(typedCond.t))
        {
          return makeExprError('Condition must be a Bool', TEWhile(typedCond, typedExpr), expr);
        }

        return makeExpr(TEWhile(typedCond, typedExpr), TVoid, expr);

      case EFor(v, it, e):
        var typedIt = typeExpr(it);
        var typedExpr = typeExpr(e);
        return makeExpr(TEFor(v, typedIt, typedExpr), TVoid, expr);

      case EBreak:
        return makeExpr(TEBreak, TVoid, expr);

      case EContinue:
        return makeExpr(TEContinue, TVoid, expr);

      case EFunction(args, e, name, ret):
        var typedArgs = [];
        for (a in args)
        {
          var typedArg =
            {
              name: a.name,
              t: a.t,
              opt: a.opt,
              value: a.value != null ? typeExpr(a.value) : null
            }
          typedArgs.push(typedArg);
        }

        var typedExpr = typeExpr(e);
        var typedRet = ret != null ? resolveType(ret) : TDynamic;

        var type = TFun([
          for (a in typedArgs)
            {
              t: (a.t != null ? resolveType(a.t) : (a.value != null ? a.value.t : TDynamic)),
              opt: (a.opt != null ? a.opt : a.value != null),
              name: a.name
            }
        ], typedRet);

        return makeExpr(TEFunction(typedArgs, typedExpr, name, ret), type, expr);

      case EReturn(e):
        var typedExpr = e != null ? typeExpr(e) : null;
        return makeExpr(TEReturn(typedExpr), typedExpr?.t ?? TVoid, expr);

      case EArray(e, index):
        var typedExpr = typeExpr(e);
        var typedIndex = typeExpr(index);
        var type = TDynamic;
        return makeExpr(TEArray(typedExpr, typedIndex), type, expr);

      case EArrayDecl(es):
        var typedExprs = [];
        for (e in es)
        {
          var typedExpr = typeExpr(e);
          typedExprs.push(typedExpr);
        }

        var type = TDynamic;
        return makeExpr(TEArrayDecl(typedExprs), type, expr);

      case ENew(cl, params):
        var typedParams = [];
        for (p in params)
        {
          var typedParam = typeExpr(p);
          typedParams.push(typedParam);
        }

        var type = TDynamic;
        return makeExpr(TENew(cl, typedParams), type, expr);

      case EThrow(e):
        var typedExpr = typeExpr(e);
        return makeExpr(TEThrow(typedExpr), typedExpr.t, expr);

      case ETry(e, v, t, ecatch):
        var typedExpr = typeExpr(e);
        var typedCatch = typeExpr(ecatch);
        return makeExpr(TETry(typedExpr, v, t, typedCatch), TVoid, expr);

      case EObject(fl):
        var typedFields = [];
        for (f in fl)
        {
          var typedField =
            {
              name: f.name,
              e: typeExpr(f.e)
            }
          typedFields.push(typedField);
        }

        var type = TDynamic;
        return makeExpr(TEObject(typedFields), type, expr);

      case ETernary(cond, e1, e2):
        var typedCond = typeExpr(cond);
        var typedExpr1 = typeExpr(e1);
        var typedExpr2 = typeExpr(e2);

        if (!isBool(typedCond.t))
        {
          return makeExprError('Condition must be a Bool', TEIf(typedCond, typedExpr1, typedExpr2), expr);
        }

        var type = TDynamic;
        return makeExpr(TETernary(typedCond, typedExpr1, typedExpr2), type, expr);

      case ESwitch(e, cases, defaultExpr):
        var typedExpr = typeExpr(e);

        var typedCases = [];
        for (c in cases)
        {
          var typedCase =
            {
              values: [for (v in c.values) typeExpr(v)],
              expr: typeExpr(c.expr)
            }
          typedCases.push(typedCase);
        }

        var typedDefaultExpr = defaultExpr != null ? typeExpr(defaultExpr) : null;

        var type = TDynamic;
        return makeExpr(TESwitch(typedExpr, typedCases, typedDefaultExpr), type, expr);

      case EDoWhile(cond, e):
        var typedCond = typeExpr(cond);
        var typedExpr = typeExpr(e);

        if (!isBool(typedCond.t))
        {
          return makeExprError('Condition must be a Bool', TEDoWhile(typedCond, typedExpr), expr);
        }

        return makeExpr(TEDoWhile(typedCond, typedExpr), TVoid, expr);

      case EMeta(name, args, e):
        var typedArgs = [];
        for (a in args)
        {
          var typedArg = typeExpr(a);
          typedArgs.push(typedArg);
        }

        var typedExpr = typeExpr(e);

        return makeExpr(TEMeta(name, typedArgs, typedExpr), typedExpr.t, expr);

      case ECheckType(e, t):
        var typedExpr = typeExpr(e);
        var type = resolveType(t);
        return makeExpr(TECheckType(typedExpr, t), type, expr);

      case EForGen(it, e):
        var typedIt = typeExpr(it);
        var typedExpr = typeExpr(e);
        return makeExpr(TEForGen(typedIt, typedExpr), TVoid, expr);
    }

    throw '$expr cannnot be typed yet, TODO';
  }

  function makeExpr(def:TypedExprDef, type:Type, expr:Expr):TypedExpr
  {
    return {
      e: def,
      t: type,
      #if hscriptPos
      pmin: expr.pmin, pmax: expr.pmax, origin: expr.origin, line: expr.line,
      #end
    }
  }

  function makeExprError(message:String, def:TypedExprDef, expr:Expr):TypedExpr
  {
    #if hscriptPos
    errors.push(new TypedExprError(message, expr.pmin, expr.pmax, expr.origin, expr.line));
    #else
    errors.push(new TypedExprError(message));
    #end
    return makeExpr(def, TUnknown, expr);
  }

  function getLocal(name:String):Null<{name:String, type:Type}>
  {
    for (i in 0...this.locals.length)
    {
      var local = this.locals[this.locals.length - 1 - i];
      if (local.name == name)
      {
        return local;
      }
    }
    return null;
  }

  function resolveType(type:CType):Type
  {
    switch (type)
    {
      case CTPath(path, params):
        var joinedPath = path.join('.');
        var params = params ?? [];

        switch (joinedPath)
        {
          case 'Null':
            return resolveType(params[0]);

          case 'Int':
            return TInt;

          case 'Float':
            return TFloat;

          case 'Bool':
            return TBool;

          case 'Dynamic':
            return TDynamic;

          default:
            var cls = HaxeType.resolveClass(joinedPath);
            if (cls != null)
            {
              return TClass(cls);
            }

            var enm = HaxeType.resolveEnum(joinedPath);
            if (enm != null)
            {
              return TEnum(enm);
            }

            throw 'SHIT';
        }

      case CTFun(args, ret):
        var typedArgs = [];
        for (a in args)
        {
          var type;
          var opt = false;
          var name = null;
          switch (a)
          {
            case CTOpt(t1):
              opt = true;
              switch (t1)
              {
                case CTNamed(n, t2):
                  name = n;
                  type = resolveType(t2);

                default:
                  type = resolveType(t1);
              }

            case CTNamed(n, t):
              name = n;
              type = resolveType(t);

            default:
              type = resolveType(a);
          }
          var typedArg =
            {
              t: type,
              opt: opt,
              name: name
            }
          typedArgs.push(typedArg);
        }

        var typedRet = resolveType(ret);

        return TFun(typedArgs, typedRet);

      case CTAnon(fields):
        var typedFields = [];
        for (f in fields)
        {
          var type;
          var opt = false;
          switch (f.t)
          {
            case CTOpt(t):
              opt = true;
              type = resolveType(t);

            default:
              type = resolveType(f.t);
          }
          var typedField =
            {
              name: f.name,
              t: type,
              opt: opt,
              meta: f.meta
            }
          typedFields.push(typedField);
        }
        return TAnonymous(typedFields);

      case CTParent(t):
        return resolveType(t);

      case CTOpt(t):
        return resolveType(t);

      case CTNamed(n, t):
        return resolveType(t);

      case CTExpr(e):
        throw '$type cannnot be resolved yet, TODO';
    }
  }

  function isEqual(type1:Type, type2:Type):Bool
  {
    if (type1 == type2) return true;

    switch [type1, type2]
    {
      case [TClass(c1), TClass(c2)]:
        return c1 == c2;

      case [TEnum(e1), TEnum(e2)]:
        return e1 == e2;

      case [TAbstract(a1), TAbstract(a2)]:
        return a1 == a2;

      case [TInt, TInt] | [TFloat, TFloat] | [TBool, TBool] | [TVoid, TVoid] | [TNull, TNull] | [TDynamic, _] | [_, TDynamic]:
        return true;

      case [TFun(args1, ret1), TFun(args2, ret2)]:
        if (args1.length != args2.length) return false;

        for (i in 0...args1.length)
        {
          var a = args1[i];
          var b = args2[i];

          if (a.opt != b.opt) return false;

          if (!isEqual(a.t, b.t)) return false;
        }

        return isEqual(ret1, ret2);

      case [TAnonymous(f1), TAnonymous(f2)]:
        if (f1.length != f2.length) return false;

        for (field in f1)
        {
          var other = null;

          for (f in f2)
            if (f.name == field.name)
            {
              other = f;
              break;
            }

          if (other == null) return false;

          if (field.opt != other.opt) return false;

          if (!isEqual(field.t, other.t)) return false;
        }

        return true;

      default:
        return false;
    }
  }

  function isNumber(type:Type):Bool
  {
    switch (type)
    {
      case TInt | TFloat | TDynamic:
        return true;

      default:
        return false;
    }
  }

  function isBool(type:Type):Bool
  {
    switch (type)
    {
      case TBool | TDynamic:
        return true;

      default:
        return false;
    }
  }

  function isDynamic(type:Type):Bool
  {
    switch (type)
    {
      case TDynamic:
        return true;

      default:
        return false;
    }
  }
}

class TypedExprError
{
  /**
   * The message of the error
   */
  public var message(default, null):String;

  #if hscriptPos
  /**
   * Start position in the code where this error occurred.
   */
  public var pmin(default, null):Int;

  /**
   * End position in the code where this error occurred.
   */
  public var pmax(default, null):Int;

  /**
   * The origin of where the error occurred.
   * This is usually the file name.
   */
  public var origin(default, null):String;

  /**
   * The line number the error occurred on.
   */
  public var line(default, null):Int;
  #end

  #if hscriptPos
  public function new(message:String, pmin:Int, pmax:Int, origin:String, line:Int)
  #else
  public function new(message:String)
  #end
  {
    this.message = message;
    #if hscriptPos
    this.pmin = pmin;
    this.pmax = pmax;
    this.origin = origin;
    this.line = line;
    #end
  }

  public function toString():String
  {
    #if hscriptPos
    return '$origin:$line: $message';
    #else
    return message;
    #end
  }
}
