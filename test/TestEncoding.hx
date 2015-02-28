import bson.Encoder;
import haxe.io.Bytes;
import mongodb.ObjectId;
import utest.Assert;
using StringTools;

class TestEncoding {
    static inline var HEX_KEY = "6b6579";

    @:access(bson.Encoder)
    public function test01_raw()
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
    public function test02_header()
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

    public function test02_document()
    {
        Assert.equals("0500000000", new Encoder().getBytes().toHex());
    }

    public function test03_elements()
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

        // string
        Assert.equals('020004000000${HEX_KEY}00', show(e().appendString("", "key")));

        // float
        Assert.equals("0100" + "".rpad("0", 16), show(e().appendFloat("", 0)));  // TODO improve

        // int
        Assert.equals("1000" + "".rpad("0", 8), show(e().appendInt("", 0)));
        Assert.equals("1000" + "04".rpad("0", 8), show(e().appendInt("", 4)));
        Assert.equals("1000" + "".rpad("f", 8), show(e().appendInt("", -1)));

        // int64
        Assert.equals("1200" + "".rpad("0", 16), show(e().appendInt64("", 0)));
        Assert.equals("1200" + "04".rpad("0", 16), show(e().appendInt64("", 4)));
        Assert.equals("1200" + "".rpad("f", 16), show(e().appendInt64("", -1)));

        // date
        Assert.equals("0900" + "78fdff7f".rpad("0", 16), show(e().appendDate("", Date.fromTime(0x7ffffd78))));

        // document
        Assert.equals("0300" + "05".rpad("0", 10), show(e().appendEmbedded("", new Encoder())));

        // ObjectId
        Assert.equals("0700" + "9bc420000100000200030000", show(e().appendObjectId("", new ObjectId(0x20c49b, 1, 2, 3))));

        // Binary
        Assert.equals("0500" + "03000000" + "00" + HEX_KEY, show(e().appendBytes("", Bytes.ofString("key"))));

        // TODO 04 0b 0d 0f 11 ff 7f
    }

    public function test91_ObjectIdMethods()
    {
        var id = new ObjectId(0x20c49b, 0x9111111, 0x82222, 0x7333333);
        Assert.equals(Date.fromTime(1e3*0x20c49b).toString(), id.getDate().toString());
        Assert.equals(0x111111, id.machineId);  // limited to 3 bytes
        Assert.equals(0x2222, id.processId);  // limited to 2 bytes
        Assert.equals(0x333333, id.counter);  // limited to 3 bytes
    }

    public function new() {}
}

