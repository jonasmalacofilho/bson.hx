import bson.Encoder;

class EncoderTools {
    public static function fullHex(enc:Encoder)
        return enc.getBytes().toHex();

    public static function toHex(enc:Encoder) {
        var bytes = enc.getBytes();
        return bytes.sub(4, bytes.length - 5).toHex();
    }
}

