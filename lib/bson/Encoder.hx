package bson;

import haxe.Int64;
import haxe.Utf8;
import haxe.io.*;
import mongodb.ObjectId;
using bson.DateTools;

import haxe.macro.Expr;
import haxe.macro.Context.*;
import haxe.macro.Type;
using haxe.macro.ExprTools;

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
        out.writeInt32(Int64.getLow(val));
        out.writeInt32(Int64.getHigh(val));
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

    public function appendEmbedded(key, val:Null<Encoder>):Encoder
    {
        if (val == null)
            return appendNull(key);
        writeHeader(key, 0x03);
        out.write(val.getBytes());
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

    // TODO appendArray

    // TODO appendObject & appendDynamic

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
                case _: break;
                }
            case TInst(_.get() => x, params):
                switch [x, params] {
                case [{ module : "String", name : "String" }, []]:  // String
                    return macro $ethis.appendString($key, $val);
                case [{ module : "Date", name : "Date" }, []]:  // Date
                    return macro $ethis.appendDate($key, $val);
                case [{ module : "mongodb.ObjectId", name : "ObjectId" }, []]:  // ObjectId
                    return macro $ethis.appendObjectId($key, $val);
                case _: break;
                }
            // TODO embedded
            // TODO bytes
            case TAbstract(_.get() => x, []):
                trace(x.pack);
                trace(x.module);
                trace(x.name);
                return ethis;
            case _: break;
            }
        }
        throw 'Macro append() not implemented for type $t (expr: ${val.toString()})';
    }

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

