import bson.Encoder;
import haxe.Int64;
import haxe.io.Bytes;
import mongodb.ObjectId;
import utest.Assert;
using StringTools;

class TestEncoding {
    static inline var HEX_KEY = "6b6579";

    @:access(bson.Encoder)
    public function test01_rawEncodings()
    {
        function cstring(s:String) {
            var e = new Encoder();
            e.writeCString(s);
            var b = e.getBytes();
            return b.sub(4, b.length - 5);  // remove document byte count and terminator
        }
        Assert.equals('${HEX_KEY}00', cstring("key").toHex());

        function string(s:String) {
            var e = new Encoder();
            e.writeString(s);
            var b = e.getBytes();
            return b.sub(4, b.length - 5);  // remove document byte count and terminator
        }
        Assert.equals('04000000${HEX_KEY}00', string("key").toHex());
    }

    @:access(bson.Encoder)
    public function test02_headerEncoding()
    {
        function r(type, key)
        {
            var e = new Encoder();
            e.writeHeader(key, type);
            var b = e.getBytes();
            return b.sub(4, b.length - 5);  // remove document byte count and terminator
        }
        Assert.equals("0100", r(1, "").toHex());
        Assert.equals('02${HEX_KEY}00', r(2, "key").toHex());
    }

    public function test02_documentStructure()
    {
        Assert.equals("0500000000", new Encoder().getBytes().toHex());
    }

    public function test03_individualAppend()
    {
        function e()
            return new Encoder();

        function show(e:Encoder)
        {
            var b = e.getBytes();
            return b.sub(4, b.length - 5).toHex();  // remove document byte count and terminator
        }

        // null
        Assert.equals("0a00", show(e().appendNull("")));

        // bool
        Assert.equals("080000", show(e().appendBool("", false)));
        Assert.equals("080001", show(e().appendBool("", true)));
        Assert.equals("0a00", show(e().appendBool("", (null : Null<Bool>))));

        // string
        Assert.equals('02000100000000', show(e().appendString("", "")));
        Assert.equals('020004000000${HEX_KEY}00', show(e().appendString("", "key")));
        Assert.equals("0a00", show(e().appendString("", (null : Null<String>))));

        // float
        Assert.equals("0100" + "".rpad("0", 16), show(e().appendFloat("", 0)));
        Assert.equals("0100" + "1f85eb51b81e0940", show(e().appendFloat("", 3.14)));
        Assert.equals("0a00", show(e().appendFloat("", (null : Null<Float>))));

        // int
        Assert.equals("1000" + "".rpad("0", 8), show(e().appendInt("", 0)));
        Assert.equals("1000" + "04".rpad("0", 8), show(e().appendInt("", 4)));
        Assert.equals("1000" + "".rpad("f", 8), show(e().appendInt("", -1)));
        Assert.equals("0a00", show(e().appendInt("", (null : Null<Int>))));

        // int64
        Assert.equals("1200" + "".rpad("0", 16), show(e().appendInt64("", Int64.ofInt(0))));
        Assert.equals("1200" + "04".rpad("0", 16), show(e().appendInt64("", Int64.ofInt(4))));
        Assert.equals("1200" + "".rpad("f", 16), show(e().appendInt64("", Int64.ofInt(-1))));
        Assert.equals("0a00", show(e().appendInt64("", (null : Null<Int64>))));

        // date
        Assert.equals("0900" + "78fdff7f".rpad("0", 16), show(e().appendDate("", Date.fromTime(0x7ffffd78))));
        Assert.equals("0a00", show(e().appendDate("", (null : Null<Date>))));

        // ObjectId
        Assert.equals("0700" + "9bc420000100000200030000", show(e().appendObjectId("", new ObjectId(0x20c49b, 1, 2, 3))));
        Assert.equals("0a00", show(e().appendObjectId("", (null : Null<ObjectId>))));

        // Binary
        Assert.equals("0500" + "03000000" + "00" + HEX_KEY, show(e().appendBytes("", Bytes.ofString("key"))));
        Assert.equals("0a00", show(e().appendBytes("", (null : Null<Bytes>))));

        // TODO 03 04 0b 0d 0f 11 ff 7f
    }

    public function test04_dynamicAppend()
    {
        function e()
            return new Encoder();

        function show(e:Encoder)
        {
            var b = e.getBytes();
            return b.sub(4, b.length - 5).toHex();  // remove document byte count and terminator
        }

        Assert.equals("0a00", show(e().appendDynamic("", null)));
        Assert.equals("080000", show(e().appendDynamic("", false)));
        Assert.equals('02000100000000', show(e().appendDynamic("", "")));
        Assert.equals("0100" + "1f85eb51b81e0940", show(e().appendDynamic("", 3.14)));
        Assert.equals("1000" + "".rpad("0", 8), show(e().appendDynamic("", 0)));
#if !java  // Type.typeof(x), x:Int64, returns TInt or TFloat on java
        Assert.equals("1200" + "".rpad("0", 16), show(e().appendDynamic("", Int64.ofInt(0))));
#end
        Assert.equals("0900" + "78fdff7f".rpad("0", 16), show(e().appendDynamic("", Date.fromTime(0x7ffffd78))));
        Assert.equals("0700" + "9bc420000100000200030000", show(e().appendDynamic("", new ObjectId(0x20c49b, 1, 2, 3))));
        // Assert.equals("0500" + "03000000" + "00" + HEX_KEY, show(e().appendDynamic("", Bytes.ofString("key"))));

        Assert.equals("0a00", show(e().appendDynamic("", (null : Null<Bool>))));
    }
    public function test05_macroAppend()
    {
        function e()
            return new Encoder();

        function show(e:Encoder)
        {
            var b = e.getBytes();
            return b.sub(4, b.length - 5).toHex();  // remove document byte count and terminator
        }

        Assert.equals("0a00", show(e().append("", null)));
        Assert.equals("080000", show(e().append("", false)));
        Assert.equals('02000100000000', show(e().append("", "")));
        Assert.equals("0100" + "".rpad("0", 16), show(e().append("", 0.)));
        Assert.equals("1000" + "".rpad("0", 8), show(e().append("", 0)));
        Assert.equals("1200" + "".rpad("0", 16), show(e().append("", Int64.ofInt(0))));
#if (haxe_ver >= 3.2)
        Assert.equals("1200" + "".rpad("0", 16), show(e().append("", (0 : Int64))));
#end
        Assert.equals("0900" + "78fdff7f".rpad("0", 16), show(e().append("", Date.fromTime(0x7ffffd78))));
        Assert.equals("0700" + "9bc420000100000200030000", show(e().append("", new ObjectId(0x20c49b, 1, 2, 3))));
        // Assert.equals("0500" + "03000000" + "00" + HEX_KEY, show(e().append("", Bytes.ofString("key"))));

        Assert.equals("0a00", show(e().append("", (null : Null<Bool>))));
    }

    public function test91_objectIdMethods()
    {
        var id = new ObjectId(0x20c49b, 0x9111111, 0x82222, 0x7333333);
        Assert.equals(Date.fromTime(1e3*0x20c49b).toString(), id.getDate().toString());
        Assert.equals(0x111111, id.machineId);  // limited to 3 bytes
        Assert.equals(0x2222, id.processId);  // limited to 2 bytes
        Assert.equals(0x333333, id.counter);  // limited to 3 bytes
    }

    public function new() {}
}

