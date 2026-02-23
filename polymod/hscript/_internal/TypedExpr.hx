package polymod.hscript._internal;

import polymod.hscript._internal.Expr;

typedef TypedExpr =
{
  var e:TypedExprDef;
  var t:Type;
  #if hscriptPos
  var pmin:Int;
  var pmax:Int;
  var origin:String;
  var line:Int;
  #end
}

enum TypedExprDef
{
  TEConst(c:TypedConst);
  TEIdent(v:String);
  TEVar(n:String, ?t:CType, ?e:TypedExpr);
  TEFinal(n:String, ?t:CType, ?e:TypedExpr);
  TEParent(e:TypedExpr);
  TEBlock(e:Array<TypedExpr>);
  TEField(e:TypedExpr, f:String);
  TEBinop(op:String, e1:TypedExpr, e2:TypedExpr);
  TEUnop(op:String, prefix:Bool, e:TypedExpr);
  TECall(e:TypedExpr, params:Array<TypedExpr>);
  TEIf(cond:TypedExpr, e1:TypedExpr, ?e2:TypedExpr);
  TEWhile(cond:TypedExpr, e:TypedExpr);
  TEFor(v:String, it:TypedExpr, e:TypedExpr);
  TEBreak;
  TEContinue;
  TEFunction(args:Array<
    {
      name:String,
      ?t:CType,
      ?opt:Bool,
      ?value:TypedExpr
    }>, e:TypedExpr, ?name:String, ?ret:CType);
  TEReturn(?e:TypedExpr);
  TEArray(e:TypedExpr, index:TypedExpr);
  TEArrayDecl(e:Array<TypedExpr>);
  TENew(cl:String, params:Array<TypedExpr>);
  TEThrow(e:TypedExpr);
  TETry(e:TypedExpr, v:String, t:Null<CType>, ecatch:TypedExpr);
  TEObject(fl:Array<{name:String, e:TypedExpr}>);
  TETernary(cond:TypedExpr, e1:TypedExpr, e2:TypedExpr);
  TESwitch(e:TypedExpr, cases:Array<{values:Array<TypedExpr>, expr:TypedExpr}>, ?defaultExpr:TypedExpr);
  TEDoWhile(cond:TypedExpr, e:TypedExpr);
  TEMeta(name:String, args:Array<TypedExpr>, e:TypedExpr);
  TECheckType(e:TypedExpr, t:CType);
  TEForGen(it:TypedExpr, e:TypedExpr);
}

enum Type
{
  TClass(c:Class<Dynamic>);
  TEnum(e:Enum<Dynamic>);
  TAbstract(a:Class<Dynamic>);
  TFun(args:Array<{t:Type, opt:Bool, ?name:String}>, ret:Type);
  TAnonymous(fields:Array<
    {
      name:String,
      t:Type,
      opt:Bool,
      ?meta:Metadata
    }>);
  TInt;
  TFloat;
  TBool;
  TDynamic;
  TVoid;
  TNull;
  TUnknown;
  // TScriptedClass();
  // TScriptedEnum();
}

enum TypedConst
{
  TCInt(i:Int);
  TCFloat(f:Float);
  TCBool(b:Bool);
  TCString(s:String, ?interpolated:Bool);
  TCNull;
}
