package polymod.hscript._internal;

#if hscript
import hscript.Expr;

@:access(hscript.Interp)
@:allow(polymod.Polymod)
class PolymodEnum 
{
  private var _e:EnumDecl;

  private var _value:String;

  private var _args:Array<Dynamic>;

  public function new(e:EnumDecl, value:String, args:Array<Dynamic>) 
  {
    this._e = e;

    var field = getField(value);

    if (field == null) 
    {
      Polymod.error(SCRIPT_PARSE_ERROR, '${e.name}.${value} does not exist.');
      return;
    }

    this._value = value;

    if (args.length != field.args.length) 
    {
      Polymod.error(SCRIPT_PARSE_ERROR, '${e.name}.${value} got the wrong number of arguments.');
      return;
    }

    this._args = args;
  }

  private function getField(name:String):Null<EnumFieldDecl> 
  {
    for (field in _e.fields) 
      {
        if (field.name == name) 
        {
          return field;
        }
      }
      return null;
  }
}
#end