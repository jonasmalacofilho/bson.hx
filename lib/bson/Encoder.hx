package bson;

import haxe.Int64;
import haxe.Utf8;
import haxe.io.*;
import mongodb.ObjectId;
using bson.DateTools;

import haxe.macro.Context.*;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

class Encoder {
    var out:BytesOutput;

    // TODO always validate
    function writeCString(cstring:String)
    {
#if debug
        if (!Utf8.validate(cstring))
            throw "Expected a UTF-8 encoded String without NULLs";
        Utf8.iter(cstring, function (c) if (c == 0) throw "Expected a UTF-8 encoded String without NULLs");
#end
        out.writeString(cstring);
        out.writeByte(0x00);
    }

    // TODO always validate
    function writeString(str:String):Void
    {
#if debug
        if (!Utf8.validate(str))
            throw "Expected a UTF-8 encoded String";
#end
        var bytes = Bytes.ofString(str);
        out.writeInt32(bytes.length + 1);
        out.write(bytes);
        out.writeByte(0x00); // terminator
    }

    function writeInt64(val:Int64)
    {
#if (haxe_ver >= 3.2)
        out.writeInt32(val.low);
        out.writeInt32(val.high);
#else
        out.writeInt32(Int64.getLow(val));
        out.writeInt32(Int64.getHigh(val));
#end
    }

    function writeHeader(key:String, type:Int):Void
    {
        out.writeByte(type);
        writeCString(key);
    }

    public function appendNull(key):Encoder
    {
        writeHeader(key, 0x0A);
        return this;
    }

    public function appendBool(key, val:Null<Bool>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x08);
        out.writeByte(val ? 0x01 : 0x00);
        return this;
    }

    public function appendString(key, val:Null<String>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x02);
        writeString(val);
        return this;
    }

    public function appendFloat(key, val:Null<Float>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x01);
        out.writeDouble(val);
        return this;
    }

    public function appendInt(key, val:Null<Int>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x10);
        out.writeInt32(val);
        return this;
    }

    public function appendInt64(key, val:Null<Int64>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x12);
        writeInt64(val);
        return this;
    }

    public function appendDate(key, val:Null<Date>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x09);
        var d64 = val.getInt64Time();
        writeInt64(d64);
        return this;
    }

    public function appendObjectId(key, val:Null<ObjectId>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x07);
        val.writeBytes(out);
        return this;
    }

    public function appendBytes(key, val:Null<Bytes>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x05);
        out.writeInt32(val.length);
        out.writeByte(0x00);  // generic binary subtype
        out.write(val);
        return this;
    }

    public function appendSub(key, val:Null<Encoder>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x03);
        out.write(val.getBytes());
        return this;
    }

    public function appendDynamic(key:String, val:Dynamic):Encoder
    {
        if (val == null)
            return appendNull(key);
        var t = std.Type.typeof(val);
        switch (t) {
        case TNull:
            return appendNull(key);
        case TBool:
            return appendBool(key, val);
        case TClass(c):
            switch (std.Type.getClassName(c)) {
            case "String":
                return appendString(key, val);
            case "haxe._Int64.___Int64", "haxe.Int64", "System.Int64":  // 3.2, 3.1.3, C#  FIXME java
                return appendInt64(key, val);
            case "Date":
                return appendDate(key, val);
            case "mongodb.ObjectId":
                return appendObjectId(key, val);
            case name:
                throw name;
                return this;
            }
        case TFloat:
            return appendFloat(key, val);
        case TInt:
            return appendInt(key, val);
        case TObject:
            var sub = new Encoder();
            for (f in Reflect.fields(val)) {
                var fval = Reflect.field(val, f);
                if (!std.Type.typeof(fval).match(TUnknown | TFunction | TEnum(_)))
                    sub.appendDynamic(f, fval);
            }
            return appendSub(key, sub);
        case TUnknown, TFunction, TEnum(_):
            throw 'Encoder.appendDynamic not implemented for type $t (val: $val)';
            return this;
        }
    }

#if macro
    static function _freeName(base:String):String
    {
        var locals = getLocalVars();
        var i = "";
        while (locals.exists(base + i))
            base += Std.parseInt(i) + 1;
        trace(base);
       return base;
    }
#end

    public macro function append(ethis:Expr, key:ExprOf<String>, val:Expr):Expr
    {
        var t = typeof(val);
        while (true) {
            switch (t) {
             case TType(_.get() => { module : "StdTypes", name : "Null" }, [of]):  // Null<T>
                 t = of;
             case TMono(_.get() => null) if (val.expr.match(EConst(CIdent("null")))):  // null literal
                 return macro $ethis.appendNull($key);
             case TAbstract(_.get() => x, params):
                 switch [x, params] {
                 case [{ module : "StdTypes", name : "Bool" }, []]:  // Bool
                     return macro $ethis.appendBool($key, $val);
                 case [{ module : "StdTypes", name : "Float" }, []]: // Float
                     return macro $ethis.appendFloat($key, $val);
                 case [{ module : "StdTypes", name : "Int" }, []]: // Int
                     return macro $ethis.appendInt($key, $val);
                 case [{ module : "haxe.Int64", name : "Int64" }, []]: // Int64
                    return macro $ethis.appendInt64($key, $val);
                case _:
                    break;
                }
            case TInst(_.get() => x, params):
                switch [x, params] {
                case [{ module : "String", name : "String" }, []]:  // string
                    return macro $ethis.appendString($key, $val);
                case [{ module : "haxe.Int64", name : "Int64" }, []]:  // int64 if haxe_ver < 3.2
                    return macro $ethis.appendInt64($key, $val);
                case [{ module : "Date", name : "Date" }, []]:  // date
                    return macro $ethis.appendDate($key, $val);
                case [{ module : "mongodb.ObjectId", name : "ObjectId" }, []]:  // objectId
                    return macro $ethis.appendObjectId($key, $val);
                case _:
                    break;
                }
            case TMono(_.get() => null) if (val.expr.match(EConst(CIdent("null")))):  // null literal
                return macro $ethis.appendNull($key);
            case TAnonymous(_.get() => anon):  // struct literal
                switch (val.expr) {
                case EObjectDecl(fields):
                    var sub = _freeName("__subencoder__");
                    var b = [];
                    b.push(macro var $sub = new bson.Encoder());
                    for (f in fields) {
                        // FIXME ignore unsupported types
                        // shouldn't be necessary if append didn't fallback to appendDynamic
                        b.push(macro $i{sub}.append($v{f.field}, ${f.expr}));
                    }
                    b.push(macro $ethis.appendSub($key, $i{sub}));
                    return { expr : EBlock(b), pos : currentPos() };
                case _:
                    break;
                }
            case TFun(_, _), TEnum(_, _):
                error('Cant use macro append for type $t (expr: ${val.toString()})', currentPos());
            case _:
                break;
            }
        }
        warning('Falling back to appendDynamic for type $t (expr: ${val.toString()})', currentPos());
        return macro $ethis.appendDynamic($key, $val);
    }

    // public macro function appendObject<T:{}>(ethis:Expr, key:ExprOf<String>, val:ExprOf<T>):Expr
    // {
    //     return macro $ethis.append($key, $val);
    // }

    // TODO appendArray

    public function getBytes():Bytes
    {
        out.writeByte(0x00);
        var res = out.getBytes();
        res.set(0x00, res.length);
        return res;
    }

    public function new()
    {
        out = new BytesOutput();
        out.bigEndian = false;
        out.writeInt32(0);  // set later
    }
}

