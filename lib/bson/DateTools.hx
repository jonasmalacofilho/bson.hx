package bson;

import haxe.Int64;
using haxe.Int64;

class DateTools {
    static var xx = 31;
    static var POWxxf = Math.pow(2, xx);
    static var POW32f = Math.pow(2, 32);

    static function unsigned(i:UInt):Float
    {
        // conversion peformed by UInt.toFloat()
        // basically, when negative, return POW32f + i
        return i;
    }

    public static function fromInt64time(ms:Int64):Date
    {
        // double = high << 32 + low
        //    with  a << b = a*(1 << b)
        return Date.fromTime(POW32f*ms.getHigh() + unsigned((ms.getLow():Int)));
    }

    public static function getInt64Time(date:Date):Int64
    {
        var t = date.getTime();
        // compute using only xx bits for each i32 part
        // to avoid problems with overflow and (TODO) precision
        var f = t/POWxxf;
        var high = Std.int(f);
        var ti = POWxxf*high;
        var low = Std.int(t - ti);  // remainder
        // trace('t: $t, f: $f, high: $high, POWxxf*high: $ti, low: $low, lowf: ${t - ti}');
        // adjust for int32
        low |= high << xx;
        high = high >> (32 - xx);
        // trace('high: $high, low: $low');
        return Int64.make(high, low);
    }
}

