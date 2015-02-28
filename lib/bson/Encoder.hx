package bson;

import haxe.Int64;
import haxe.io.*;
import haxe.Utf8;
using bson.DateTools;

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
        out.writeBytes(bytes, 0, bytes.length);
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

    public function appendBool(key, val:Bool):Encoder
    {
        writeHeader(key, 0x08);
        out.writeByte(val ? 0x01 : 0x00);
        return this;
    }

    public function appendString(key, val:String):Encoder
    {
        writeHeader(key, 0x02);
        writeString(val);
        return this;
    }

    public function appendFloat(key, val:Float):Encoder
    {
        writeHeader(key, 0x01);
        out.writeDouble(val);
        return this;
    }

    public function appendInt(key, val:Int):Encoder
    {
        writeHeader(key, 0x10);
        out.writeInt32(val);
        return this;
    }

    public function appendInt64(key, val:Int64):Encoder
    {
        writeHeader(key, 0x12);
        writeInt64(val);
        return this;
    }

    public function appendDate(key, val:Date):Encoder
    {
        writeHeader(key, 0x09);
        var d64 = val.getInt64Time();
        writeInt64(d64);
        return this;
    }

    // public function appendArray<T>(key, val:Array<T>):Encoder
    // {
    //     writeHeader(key, 0x04);
    //     var bytes = arrayToBytes(val);
    //     out.writeInt32(bytes.length + 4);
    //     out.writeBytes(bytes, 0, bytes.length);
        // return this;
    // }

    // public function appendObjectId(key, val:ObjectId):Encoder
    // {
    //     writeHeader(key, 0x07);
    //     out.writeBytes(val.bytes, 0, 12);
        // return this;
    // }

    public function appendEmbedded(key, val:Encoder):Encoder
    {
        writeHeader(key, 0x03);
        out.write(val.getBytes());
        return this;
    }

    // public function writeDynamic(key, val:Dynamic)
    // {
    //     writeHeader(key, 0x03);
    //     var bytes = objectToBytes(val);
    //     out.writeInt32(bytes.length + 4);
    //     out.writeBytes(bytes, 0, bytes.length);
        // return this;
    // }

    public function getBytes():Bytes
    {
        out.writeByte(0);
        var res = out.getBytes();
        res.set(0, res.length);
        return res;
    }

    public function new()
    {
        out = new BytesOutput();
        out.bigEndian = false;
        out.writeInt32(0);  // set later
    }
}

