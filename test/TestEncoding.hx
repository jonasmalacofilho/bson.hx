import bson.Encoder;
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
            return e.getBytes();
        }
        Assert.equals('${HEX_KEY}00', cstring("key").toHex());

        function string(s:String) {
            var e = new Encoder();
            e.writeString(s);
            return e.getBytes();
        }
        Assert.equals('04000000${HEX_KEY}00', string("key").toHex());
        
        // TODO Int64
    }

    @:access(bson.Encoder)
    public function test02_header()
    {
        function r(type, key)
        {
            var e = new Encoder();
            e.writeHeader(key, type);
            return e.getBytes();
        }
        Assert.equals("0100", r(1, "").toHex());
        Assert.equals('02${HEX_KEY}00', r(2, "key").toHex());
    }

    public function test02_elements()
    {
        function e()
            return new Encoder();

        // null
        Assert.equals("0a00", e().appendNull("").getBytes().toHex());

        // bool
        Assert.equals("080000", e().appendBool("", false).getBytes().toHex());
        Assert.equals("080001", e().appendBool("", true).getBytes().toHex());

        // string
        Assert.equals('020004000000${HEX_KEY}00', e().appendString("", "key").getBytes().toHex());

        // float
        Assert.equals("0100" + "".rpad("0", 16), e().appendFloat("", 0).getBytes().toHex());  // TODO improve

        // int
        Assert.equals("1000" + "".rpad("0", 8), e().appendInt("", 0).getBytes().toHex());
        Assert.equals("1000" + "04".rpad("0", 8), e().appendInt("", 4).getBytes().toHex());
        Assert.equals("1000" + "".rpad("f", 8), e().appendInt("", -1).getBytes().toHex());

        // TODO 03 04 05 07 09 0b 0d 0f 11 12 ff 7f
    }

    public function new() {}

}

