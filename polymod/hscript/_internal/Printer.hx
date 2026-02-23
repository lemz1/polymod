/*
 * Copyright (C)2008-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package polymod.hscript._internal;

import polymod.hscript._internal.Expr;
import polymod.hscript._internal.TypedExpr;

/**
 * Utility class for converting HScript elements into human-readable `String` representations.
 */
class Printer
{
  var buf:StringBuf;
  var tabs:String;

  public function new() {}

  /**
   * Converts an HScript AST node into a human-readable `String` representation.
   * @param e The node to convert.
   * @return String
   */
  public function exprToString(e:Expr):String
  {
    buf = new StringBuf();
    tabs = "";
    expr(e);
    return buf.toString();
  }

  /**
   * Converts a Typed HScript AST node into a human-readable `String` representation.
   * @param e The node to convert.
   * @return String
   */
  public function typedExprToString(e:TypedExpr):String
  {
    buf = new StringBuf();
    tabs = "";
    typedExpr(e);
    return buf.toString();
  }

  /**
   * Converts a type into a human-readable `String` representation.
   * @param t The type to convert.
   * @return String
   */
  public function typeToString(t:CType):String
  {
    buf = new StringBuf();
    tabs = "";
    type(t);
    return buf.toString();
  }

  inline function add<T>(s:T):Void
    buf.add(s);

  function type(t:CType):Void
  {
    switch (t)
    {
      case CTOpt(t):
        add('?');
        type(t);
      case CTPath(path, params):
        add(path.join("."));
        if (params != null)
        {
          add("<");
          var first = true;
          for (p in params)
          {
            if (first) first = false
            else
              add(", ");
            type(p);
          }
          add(">");
        }
      case CTNamed(name, t):
        add(name);
        add(':');
        type(t);
      case CTFun(args, ret) if (Lambda.exists(args, function(a) return a.match(CTNamed(_, _)))):
        add('(');
        for (a in args)
          switch a
          {
            case CTNamed(_, _): type(a);
            default: type(CTNamed('_', a));
          }
        add(')->');
        type(ret);
      case CTFun(args, ret):
        if (args.length == 0) add("Void -> ");
        else
        {
          for (a in args)
          {
            type(a);
            add(" -> ");
          }
        }
        type(ret);
      case CTAnon(fields):
        add("{");
        var first = true;
        for (f in fields)
        {
          if (first)
          {
            first = false;
            add(" ");
          }
          else
            add(", ");
          add(f.name + " : ");
          type(f.t);
        }
        add(first ? "}" : " }");
      case CTParent(t):
        add("(");
        type(t);
        add(")");
      case CTExpr(e):
        expr(e);
    }
  }

  function addType(t:CType):Void
  {
    if (t != null)
    {
      add(" : ");
      type(t);
    }
  }

  function addConst(c:Const):Void
  {
    switch (c)
    {
      case CInt(i):
        add(i);
      case CFloat(f):
        add(f);
      case CString(s):
        add('"');
        add(s.split('"')
          .join('\\"')
          .split("\n")
          .join("\\n")
          .split("\r")
          .join("\\r")
          .split("\t")
          .join("\\t"));
        add('"');
    }
  }

  function expr(e:Expr):Void
  {
    if (e == null)
    {
      add("??NULL??");
      return;
    }
    switch (#if hscriptPos e.e #else e #end)
    {
      case EConst(c):
        addConst(c);
      case EIdent(v):
        add(v);
      case EVar(n, t, e):
        add("var " + n);
        addType(t);
        if (e != null)
        {
          add(" = ");
          expr(e);
        }
      case EFinal(n, t, e):
        add("final " + n);
        addType(t);
        if (e != null)
        {
          add(" = ");
          expr(e);
        }
      case EParent(e):
        add("(");
        expr(e);
        add(")");
      case EBlock(el):
        if (el.length == 0)
        {
          add("{}");
        }
        else
        {
          tabs += "\t";
          add("{\n");
          for (e in el)
          {
            add(tabs);
            expr(e);
            add(";\n");
          }
          tabs = tabs.substr(1);
          add("}");
        }
      case EField(e, f):
        expr(e);
        add("." + f);
      case EBinop(op, e1, e2):
        expr(e1);
        add(" " + op + " ");
        expr(e2);
      case EUnop(op, pre, e):
        if (pre)
        {
          add(op);
          expr(e);
        }
        else
        {
          expr(e);
          add(op);
        }
      case ECall(e, args):
        if (e == null) expr(e);
        else
          switch (#if hscriptPos e.e #else e #end)
          {
            case EField(_), EIdent(_), EConst(_):
              expr(e);
            default:
              add("(");
              expr(e);
              add(")");
          }
        add("(");
        var first = true;
        for (a in args)
        {
          if (first) first = false
          else
            add(", ");
          expr(a);
        }
        add(")");
      case EIf(cond, e1, e2):
        add("if( ");
        expr(cond);
        add(" ) ");
        expr(e1);
        if (e2 != null)
        {
          add(" else ");
          expr(e2);
        }
      case EWhile(cond, e):
        add("while( ");
        expr(cond);
        add(" ) ");
        expr(e);
      case EDoWhile(cond, e):
        add("do ");
        expr(e);
        add(" while ( ");
        expr(cond);
        add(" )");
      case EFor(v, it, e):
        add("for( " + v + " in ");
        expr(it);
        add(" ) ");
        expr(e);
      case EForGen(it, e):
        add("for( ");
        expr(it);
        add(" ) ");
        expr(e);
      case EBreak:
        add("break");
      case EContinue:
        add("continue");
      case EFunction(params, e, name, ret):
        add("function");
        if (name != null) add(" " + name);
        add("(");
        var first = true;
        for (a in params)
        {
          if (first) first = false
          else
            add(", ");
          if (a.opt) add("?");
          add(a.name);
          addType(a.t);
        }
        add(")");
        addType(ret);
        add(" ");
        expr(e);
      case EReturn(e):
        add("return");
        if (e != null)
        {
          add(" ");
          expr(e);
        }
      case EArray(e, index):
        expr(e);
        add("[");
        expr(index);
        add("]");
      case EArrayDecl(el):
        add("[");
        var first = true;
        for (e in el)
        {
          if (first) first = false
          else
            add(", ");
          expr(e);
        }
        add("]");
      case ENew(cl, args):
        add("new " + cl + "(");
        var first = true;
        for (e in args)
        {
          if (first) first = false
          else
            add(", ");
          expr(e);
        }
        add(")");
      case EThrow(e):
        add("throw ");
        expr(e);
      case ETry(e, v, t, ecatch):
        add("try ");
        expr(e);
        add(" catch( " + v);
        addType(t);
        add(") ");
        expr(ecatch);
      case EObject(fl):
        if (fl.length == 0)
        {
          add("{}");
        }
        else
        {
          tabs += "\t";
          add("{\n");
          for (f in fl)
          {
            add(tabs);
            add(f.name + " : ");
            expr(f.e);
            add(",\n");
          }
          tabs = tabs.substr(1);
          add("}");
        }
      case ETernary(c, e1, e2):
        expr(c);
        add(" ? ");
        expr(e1);
        add(" : ");
        expr(e2);
      case ESwitch(e, cases, def):
        add("switch( ");
        expr(e);
        add(") {");
        for (c in cases)
        {
          add("case ");
          var first = true;
          for (v in c.values)
          {
            if (first) first = false
            else
              add(", ");
            expr(v);
          }
          add(": ");
          expr(c.expr);
          add(";\n");
        }
        if (def != null)
        {
          add("default: ");
          expr(def);
          add(";\n");
        }
        add("}");
      case EMeta(name, args, e):
        add("@");
        add(name);
        if (args != null && args.length > 0)
        {
          add("(");
          var first = true;
          for (a in args)
          {
            if (first) first = false
            else
              add(", ");
            expr(e);
          }
          add(")");
        }
        add(" ");
        expr(e);
      case ECheckType(e, t):
        add("(");
        expr(e);
        add(" : ");
        addType(t);
        add(")");
    }
  }

  function runtimeType(t:Type):Void
  {
    if (t == null)
    {
      add("Unknown");
      return;
    }

    switch (t)
    {
      case TInt:
        add("Int");

      case TFloat:
        add("Float");

      case TBool:
        add("Bool");

      case TVoid:
        add("Void");

      case TDynamic:
        add("Dynamic");

      case TNull:
        add("Null");

      case TUnknown:
        add("Unknown");

      case TClass(c):
        var name = Type.getClassName(c);
        add(name != null ? name : "Class");

      case TEnum(e):
        var name = Type.getEnumName(e);
        add(name != null ? name : "Enum");

      case TAbstract(a):
        var name = Type.getClassName(a);
        add(name != null ? name : "Abstract");

      case TFun(args, ret):
        add("(");

        var first = true;
        for (a in args)
        {
          if (!first) add(", ");
          first = false;

          if (a.name != null) add(a.name + ":");

          runtimeType(a.t);
        }

        add(") -> ");
        runtimeType(ret);

      case TAnonymous(fields):
        add("{");

        var first = true;
        for (f in fields)
        {
          if (!first) add(", ");
          first = false;

          if (f.opt) add("?");

          add(f.name + ":");
          runtimeType(f.t);
        }

        add("}");
    }
  }

  function addTypedConst(c:TypedConst):Void
{
  switch (c)
  {
    case TCInt(i):
      add(i);
    case TCFloat(f):
      add(f);
    case TCBool(b):
      add(b ? "true" : "false");
    case TCString(s, _):
      add('"');
      add(s.split('"').join('\\"')
        .split("\n").join("\\n")
        .split("\r").join("\\r")
        .split("\t").join("\\t"));
      add('"');
    case TCNull:
      add("null");
  }
}

  function typedExpr(e:TypedExpr):Void
  {
    if (e == null)
    {
      add("??NULL??");
      return;
    }

    add("(");

    switch (e.e)
    {
      case TEConst(c):
        addTypedConst(c);

      case TEIdent(v):
        add(v);

      case TEVar(n, t, e2):
        add("var " + n);
        addType(t);
        if (e2 != null)
        {
          add(" = ");
          typedExpr(e2);
        }

      case TEFinal(n, t, e2):
        add("final " + n);
        addType(t);
        if (e2 != null)
        {
          add(" = ");
          typedExpr(e2);
        }

      case TEParent(e2):
        add("(");
        typedExpr(e2);
        add(")");

      case TEBlock(el):
        if (el.length == 0)
        {
          add("{}");
        }
        else
        {
          tabs += "\t";
          add("{\n");
          for (x in el)
          {
            add(tabs);
            typedExpr(x);
            add(";\n");
          }
          tabs = tabs.substr(1);
          add("}");
        }

      case TEField(e2, f):
        typedExpr(e2);
        add("." + f);

      case TEBinop(op, e1, e2):
        typedExpr(e1);
        add(" " + op + " ");
        typedExpr(e2);

      case TEUnop(op, prefix, e2):
        if (prefix)
        {
          add(op);
          typedExpr(e2);
        }
        else
        {
          typedExpr(e2);
          add(op);
        }

      case TECall(e2, params):
        typedExpr(e2);
        add("(");

        var first = true;
        for (p in params)
        {
          if (!first) add(", ");
          first = false;
          typedExpr(p);
        }

        add(")");

      case TEIf(cond, e1, e2):
        add("if( ");
        typedExpr(cond);
        add(" ) ");
        typedExpr(e1);

        if (e2 != null)
        {
          add(" else ");
          typedExpr(e2);
        }

      case TEWhile(cond, e2):
        add("while( ");
        typedExpr(cond);
        add(" ) ");
        typedExpr(e2);

      case TEDoWhile(cond, e2):
        add("do ");
        typedExpr(e2);
        add(" while( ");
        typedExpr(cond);
        add(" )");

      case TEFor(v, it, e2):
        add("for( " + v + " in ");
        typedExpr(it);
        add(" ) ");
        typedExpr(e2);

      case TEForGen(it, e2):
        add("for( ");
        typedExpr(it);
        add(" ) ");
        typedExpr(e2);

      case TEBreak:
        add("break");

      case TEContinue:
        add("continue");

      case TEFunction(args, body, name, ret):
        add("function");
        if (name != null) add(" " + name);

        add("(");

        var first = true;
        for (a in args)
        {
          if (!first) add(", ");
          first = false;

          if (a.opt == true) add("?");
          add(a.name);
          addType(a.t);
        }

        add(")");
        addType(ret);
        add(" ");
        typedExpr(body);

      case TEReturn(e2):
        add("return");
        if (e2 != null)
        {
          add(" ");
          typedExpr(e2);
        }

      case TEArray(e2, index):
        typedExpr(e2);
        add("[");
        typedExpr(index);
        add("]");

      case TEArrayDecl(arr):
        add("[");
        var first = true;
        for (x in arr)
        {
          if (!first) add(", ");
          first = false;
          typedExpr(x);
        }
        add("]");

      case TENew(cl, params):
        add("new " + cl + "(");
        var first = true;
        for (p in params)
        {
          if (!first) add(", ");
          first = false;
          typedExpr(p);
        }
        add(")");

      case TEThrow(e2):
        add("throw ");
        typedExpr(e2);

      case TETry(e2, v, t, ecatch):
        add("try ");
        typedExpr(e2);
        add(" catch( " + v);
        addType(t);
        add(" ) ");
        typedExpr(ecatch);

      case TEObject(fl):
        if (fl.length == 0)
        {
          add("{}");
        }
        else
        {
          tabs += "\t";
          add("{\n");
          for (f in fl)
          {
            add(tabs);
            add(f.name + " : ");
            typedExpr(f.e);
            add(",\n");
          }
          tabs = tabs.substr(1);
          add("}");
        }

      case TETernary(c, e1, e2):
        typedExpr(c);
        add(" ? ");
        typedExpr(e1);
        add(" : ");
        typedExpr(e2);

      case TESwitch(e2, cases, def):
        add("switch( ");
        typedExpr(e2);
        add(") {");

        for (c in cases)
        {
          add("case ");
          var first = true;
          for (v in c.values)
          {
            if (!first) add(", ");
            first = false;
            typedExpr(v);
          }
          add(": ");
          typedExpr(c.expr);
          add(";\n");
        }

        if (def != null)
        {
          add("default: ");
          typedExpr(def);
          add(";\n");
        }

        add("}");

      case TEMeta(name, args, e2):
        add("@");
        add(name);

        if (args != null && args.length > 0)
        {
          add("(");
          var first = true;
          for (a in args)
          {
            if (!first) add(", ");
            first = false;
            typedExpr(a);
          }
          add(")");
        }

        add(" ");
        typedExpr(e2);

      case TECheckType(e2, t):
        add("(");
        typedExpr(e2);
        add(" : ");
        type(t);
        add(")");
    }

    add(" : ");
    runtimeType(e.t);

    add(")");
  }

  /**
   * Same as `exprToString`, but without the need to create a Printer.
   * @param e The AST node to convert.
   * @return String
   */
  public static function toString(e:Expr):String
  {
    return new Printer().exprToString(e);
  }

  /**
   * Converts an `Error` object into a human-readable `String` representation.
   * @param e The error to convert.
   * @param includePosInfo Prepends the origin and line position number, only works if `hscriptPos` is defined.
   * @return String
   */
  public static function errorToString(e:Expr.Error, includePosInfo:Bool = true):String
  {
    var message = switch (#if hscriptPos e.e #else e #end)
    {
      case EInvalidChar(c): "Invalid character: '" + (StringTools.isEof(c) ? "EOF" : String.fromCharCode(c)) + "' (" + c + ")";
      case EUnexpected(s): "Unexpected token: \"" + s + "\"";
      case EUnterminatedString: "Unterminated string";
      case EUnterminatedComment: "Unterminated comment";
      case EInvalidPreprocessor(str): "Invalid preprocessor (" + str + ")";
      case EUnknownVariable(v): "Unknown variable: " + v;
      case EInvalidIterator(v): "Invalid iterator: " + v;
      case EInvalidOp(op): "Invalid operator: " + op;
      case EInvalidAccess(f): "Invalid access to field " + f;
      case EInvalidModule(m): "Invalid module: " + m;
      case EBlacklistedModule(m): "Blacklisted module: " + m;
      case EBlacklistedField(m): "Blacklisted field: " + m;
      case EInvalidArgCount(f, expected, given): 'Invalid number of given arguments. Got $given, required $expected' + f;
      case EPurgedFunction(f): "Invalid access to purged function (did it throw an uncaught exception earlier?): " + f;
      case ENullObjectReference(f): "Invalid reference to field of a null object: " + f;
      case EInvalidInStaticContext(v): "Invalid field access from static context: " + v;
      case EInvalidScriptedFnAccess(f): "Invalid function access to scripted class: " + f;
      case EInvalidScriptedVarGet(v): "Invalid variable retrieval to scripted class: " + v;
      case EInvalidScriptedVarSet(v): "Invalid variable assignment to scripted class: " + v;
      case EInvalidFinalSet(f): "Invalid final field assignment: " + f;
      case EInvalidPropGet(p): "Cannot access property " + p + " for reading";
      case EInvalidPropSet(p): "Cannot access property " + p + " for writing";
      case EPropVarNotReal(p): "Cannot access property " + p + " because it is not a real variable";
      case EClassSuperNotCalled: "Super constructor not called";
      case EClassInvalidSuper: "Unexpected \"super\" in class that does not extend anything.";
      case EClassUnresolvedSuperclass(c, r): 'Unresolved superclass $c (reason: $r)';
      // TODO: Do we need to distinguish these?
      case EScriptCallThrow(v): "Script threw an exception: " + v;
      case EScriptThrow(v): "User script threw an exception: " + v;
      case ECustom(msg): msg;
    };
    #if hscriptPos
    if (includePosInfo) message = e.origin + ":" + e.line + ": " + message;
    #end
    return message;
  }
}
