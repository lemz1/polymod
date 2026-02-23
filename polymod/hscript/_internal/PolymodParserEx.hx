package polymod.hscript._internal;

import polymod.hscript._internal.Parser;
import polymod.hscript._internal.Expr;

class PolymodParserEx extends Parser
{
  public override function parseModule(content:String, ?origin:String = "hscript", ?position = 0)
  {
    return super.parseModule(content, origin, position);
  }
}
