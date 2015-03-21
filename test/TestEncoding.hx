import bson.Encoder;
import haxe.Int64;
import haxe.io.Bytes;
import mongodb.ObjectId;
import utest.Assert;
using EncoderTools;
using StringTools;

class TestEncoding {
    function e():Encoder
    {
        return new Encoder();
    }

    @:access(bson.Encoder)
    public function test01_encodeCString()
    {
        var enc = e();
        enc.writeCString("key");
        Assert.equals("6b657900", enc.toHex());
    }

    @:access(bson.Encoder)
    public function test02_encodeString()
    {
        var enc = e();
        enc.writeString("key");
        Assert.equals("040000006b657900", enc.toHex());
    }

    @:access(bson.Encoder)
    public function test21_headerEncoding()
    {
        function test(type, key)
        {
            var enc = e();
            enc.writeHeader(key, type);
            return enc.toHex();
        }
        Assert.equals("0100", test(1, ""));
        Assert.equals("026b657900", test(2, "key"));
    }

    public function test22_documentStructure()
    {
        Assert.equals("0500000000", e().fullHex());
    }

    public function test31_individualAppend()
    {
        // TODO 03 04 0b 0d 0f 11 ff 7f

        // null
        Assert.equals("0a00", e().appendNull("").toHex());

        // bool
        Assert.equals("0800" + "00", e().appendBool("", false).toHex());
        Assert.equals("0800" + "01", e().appendBool("", true).toHex());
        Assert.equals("0a00", e().appendBool("", (null : Null<Bool>)).toHex());

        // string
        Assert.equals("0200" + "0100000000", e().appendString("", "").toHex());
        Assert.equals("0200" + "040000006b657900", e().appendString("", "key").toHex());
        Assert.equals("0a00", e().appendString("", (null : Null<String>)).toHex());

        // float
        Assert.equals("0100" + "0000000000000000", e().appendFloat("", 0).toHex());
        Assert.equals("0100" + "1f85eb51b81e0940", e().appendFloat("", 3.14).toHex());
        Assert.equals("0a00", e().appendFloat("", (null : Null<Float>)).toHex());

        // int
        Assert.equals("1000" + "00000000", e().appendInt("", 0).toHex());
        Assert.equals("1000" + "04000000", e().appendInt("", 4).toHex());
        Assert.equals("1000" + "ffffffff", e().appendInt("", -1).toHex());
        Assert.equals("0a00", e().appendInt("", (null : Null<Int>)).toHex());

        // int64
        Assert.equals("1200" + "0000000000000000", e().appendInt64("", Int64.ofInt(0)).toHex());
        Assert.equals("1200" + "0400000000000000", e().appendInt64("", Int64.ofInt(4)).toHex());
        Assert.equals("1200" + "ffffffffffffffff", e().appendInt64("", Int64.ofInt(-1)).toHex());
        Assert.equals("0a00", e().appendInt64("", (null : Null<Int64>)).toHex());

        // date
        Assert.equals("0900" + "78fdff7f00000000", e().appendDate("", Date.fromTime(0x7ffffd78)).toHex());
        Assert.equals("0a00", e().appendDate("", (null : Null<Date>)).toHex());

        // ObjectId
        Assert.equals("0700" + "9bc42000" + "010000" + "0200" + "030000", e().appendObjectId("", new ObjectId(0x20c49b, 1, 2, 3)).toHex());
        Assert.equals("0a00", e().appendObjectId("", (null : Null<ObjectId>)).toHex());

        // bytes
        Assert.equals("0500" + "03000000" + "00" + "6b6579", e().appendBytes("", Bytes.ofString("key")).toHex());
        Assert.equals("0a00", e().appendBytes("", (null : Null<Bytes>)).toHex());
    }

    public function test32_dynamicAppend()
    {
        Assert.equals("0a00", e().appendDynamic("", null).toHex());
        Assert.equals("0800" + "00", e().appendDynamic("", false).toHex());
        Assert.equals("0200" + "0100000000", e().appendDynamic("", "").toHex());
        Assert.equals("0100" + "1f85eb51b81e0940", e().appendDynamic("", 3.14).toHex());
        Assert.equals("1000" + "00000000", e().appendDynamic("", 0).toHex());
#if !java  // Type.typeof(x), x:Int64, returns TInt or TFloat on java
        Assert.equals("1200" + "0000000000000000", e().appendDynamic("", Int64.ofInt(0)).toHex());
#end
        Assert.equals("0900" + "78fdff7f00000000", e().appendDynamic("", Date.fromTime(0x7ffffd78)).toHex());
        Assert.equals("0700" + "9bc42000" + "010000" + "0200" + "030000", e().appendDynamic("", new ObjectId(0x20c49b, 1, 2, 3)).toHex());
        Assert.equals("0500" + "03000000" + "00" + "6b6579", e().appendDynamic("", Bytes.ofString("key")).toHex());
    }

    public function test33_macroAppend()
    {
        Assert.equals("0a00", e().append("", null).toHex());
        Assert.equals("0800" + "00", e().append("", false).toHex());
        Assert.equals("0200" + "0100000000", e().append("", "").toHex());
        Assert.equals("0100" + "0000000000000000", e().append("", 0.).toHex());
        Assert.equals("1000" + "00000000", e().append("", 0).toHex());
        Assert.equals("1200" + "0000000000000000", e().append("", Int64.ofInt(0)).toHex());
#if (haxe_ver >= 3.2)
        Assert.equals("1200" + "0000000000000000", e().append("", (0 : Int64)).toHex());
#end
        Assert.equals("0900" + "78fdff7f00000000", e().append("", Date.fromTime(0x7ffffd78)).toHex());
        Assert.equals("0700" + "9bc42000" + "010000" + "0200" + "030000", e().append("", new ObjectId(0x20c49b, 1, 2, 3)).toHex());
        Assert.equals("0500" + "03000000" + "00" + "6b6579", e().append("", Bytes.ofString("key")).toHex());
        // Null<T>
        Assert.equals("0a00", e().append("", (null : Null<Bool>)).toHex());
    }

    public function test41_objectAppend()
    {
        // struct literal
        Assert.equals("0300" + "0500000000", e().append("", {}).toHex());
        Assert.equals("0300" + "0a0000000a6b65790000", e().append("", { key : null }).toHex());
        Assert.equals("0300" + "0b000000086b6579000000", e().append("", { key : false }).toHex());
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

