package mongodb;

import haxe.io.*;

class ObjectId {
    public var timestamp(default, null):Int;
    public var machineId(default, null):Int;
    public var processId(default, null):Int;
    public var counter(default, null):Int;

    public function writeBytes(out:BytesOutput)
    {
        out.writeInt32(timestamp);
        out.writeInt24(machineId);
        out.writeInt16(processId);
        out.writeInt24(counter);
    }

    public function getDate()
    {
        return Date.fromTime(1e3*timestamp);
    }

    public function toString()
    {
        return 'ObjectId(${valueOf()})';
    }

    public function valueOf()
    {
        var out = new BytesOutput();
        out.bigEndian = false;
        writeBytes(out);
        return out.getBytes().toHex();
    }

    public function new(timestamp:Int, machineId:Int, processId:Int, counter:Int)
    {
        this.timestamp = timestamp;
        this.machineId = machineId & 0xffffff;  // equivalent to machineId % 0x1ffffff
        this.processId = processId & 0xffff;
        this.counter = counter & 0xffffff;
    }

    public static function make(counter:Null<Int>, ?timestamp:Null<Int>, ?machineId:Null<Int>, ?processId:Null<Int>)
    {
        if (timestamp == null)
            timestamp = Std.int(Date.now().getTime()*1e-3);
        if (machineId == null)
            machineId = 0;  // TODO try to get something to fill this
        if (processId == null)
            processId = 0;  // TODO try to get the process id or something else to fill this
    }
}

