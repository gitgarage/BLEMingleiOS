import Foundation
import CoreBluetooth

extension String {
    subscript  (r: Range<Int>) -> String {
        get {
            let subStart = advance(self.startIndex, r.startIndex, self.endIndex)
            let subEnd = advance(subStart, r.endIndex - r.startIndex, self.endIndex)
            return self.substringWithRange(Range(start: subStart, end: subEnd))
        }
    }

    func dataFromHexadecimalString() -> NSData? {
        let trimmedString = self.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<> ")).stringByReplacingOccurrencesOfString(" ", withString: "")

        // make sure the cleaned up string consists solely of hex digits, and that we have even number of them

        let regex = NSRegularExpression(pattern: "^[0-9a-f]*$", options: .CaseInsensitive, error: nil)
         
        let found = regex!.firstMatchInString(trimmedString, options: nil, range: NSMakeRange(0, count(trimmedString)))
        if found == nil || found?.range.location == NSNotFound || count(trimmedString) % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData

        let data = NSMutableData(capacity: count(trimmedString) / 2)

        for var index = trimmedString.startIndex; index < trimmedString.endIndex; index = index.successor().successor() {
            let byteString = trimmedString.substringWithRange(Range<String.Index>(start: index, end: index.successor().successor()))
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data?.appendBytes([num] as [UInt8], length: 1)
        }

        return data
    }
}

extension NSData {
    func toHexString() -> String {

        let string = NSMutableString(capacity: length * 2)
        var byte: UInt8 = 0

        for i in 0 ..< length {
            getBytes(&byte, range: NSMakeRange(i, 1))
            string.appendFormat("%02x", byte)
        }

        return string as String
    }
}

class BLEMingle: NSObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {

    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic!
    var dataToSend: NSData!
    var sendDataIndex: Int!
    var datastring: String!
    var sendingEOM: Bool = false
    let MAX_TRANSFER_DATA_LENGTH: Int = 20
    let TRANSFER_SERVICE_UUID:String = "E20A39F4-73F5-4BC4-A12F-17D1AD07A961"
    let TRANSFER_CHARACTERISTIC_UUID:String = "08590F7E-DB05-467E-8757-72F6FAEB13D4"
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral!
    var data: NSMutableData!
    var finalString: String!
    var lastString: NSString!
    var usedList: [String]!
    var newList: [String]!
    var delegate: BLECentralDelegate?

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        data = NSMutableData()
        finalString = ""
        lastString = ""
        usedList = ["Zygats","Quiltiberry"]
        newList = usedList
        print("initCentral")
    }

    func startScan() {
        centralManager.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])

        print("Scanning started")
    }

    func didDiscoverPeripheral(peripheral: CBPeripheral!) -> CBPeripheral! {
        if (peripheral != nil)
        {
            return peripheral;
        }
        return nil
    }

    func stopScan() {
        centralManager.stopScan()

        print("Scanning stopped")
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {

    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!){

        delegate?.didDiscoverPeripheral(peripheral)
        var splitUp = split("\(advertisementData)") {$0 == "\n"}.map { String($0) }
        if (splitUp.count > 1)
        {
            var chop = splitUp[1]
            chop = chop[0...count(chop)-2]
            var chopSplit = split("\(chop)") {$0 == "\""}.map { String($0) }

            if !(chopSplit.count > 1 && chopSplit[1] == "Device Information")
            {
                var hexString = chop[4...7] + chop[12...19] + chop[21...26]
                var datas = hexString.dataFromHexadecimalString()
                var string = NSString(data: datas!, encoding: NSUTF8StringEncoding) as! String
                if (!contains(usedList, string))
                {
                    usedList.append(string)
                    if (count(string) == 9 && string[count(string)-1...count(string)-1] == "-")
                    {
                        finalString = finalString + string[0...count(string)-2]
                    }
                    else
                    {
                        lastString = finalString + string + "\n"
                        print(lastString)
                        finalString = ""
                        usedList = newList
                        usedList.append(string)
                    }
                }
            }
        }
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {

    }

    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {

        print("Connected to peripheral: \(peripheral)")

        peripheral.delegate = self

        peripheral.discoverServices([CBUUID(string: TRANSFER_SERVICE_UUID)])
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if error != nil {
            return
        }

        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)], forService: service as! CBService)
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {

        print("didDiscoverCharacteristicsForService: \(service)")

        for characteristic in service.characteristics ?? [] {
            if ((characteristic as! CBCharacteristic).UUID.isEqual(CBUUID(string: TRANSFER_CHARACTERISTIC_UUID))) {
                print("Discovered characteristic: \(characteristic)")
                peripheral .setNotifyValue(true, forCharacteristic: characteristic as! CBCharacteristic)
            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            return
        }

        var stringFromData = NSString(data: characteristic.value!, encoding: NSUTF8StringEncoding)

        if (stringFromData! == "EOM") {
            print("Data Received: \(NSString(data: data, encoding: NSUTF8StringEncoding))")
            data.length = 0
            //            peripheral.setNotifyValue(false, forCharacteristic: characteristic)
            //            centralManager.cancelPeripheralConnection(peripheral)
        }
        else {
            data.appendData(characteristic.value!)
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            return
        }

        if !characteristic.UUID.isEqual(CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)) {
            return
        }

        if characteristic.isNotifying {
            print("Notification began on: \(characteristic)")
        }
        else {
            print("Notification stopped on: \(characteristic). Disconnecting")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Peripheral Disconnected")
        discoveredPeripheral = nil
    }

    func StringToUUID(hex: String) -> String
    {
        var rev = String(reverse(hex))
        var hexData: NSData! = rev.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        rev = hexData.toHexString()
        while(count(rev) < 32) {
            rev = "0" + rev;
        }
        rev = rev[0...31]
        var finalString = rev[0...7] + "-" + rev[8...11] + "-" + rev[12...15] + "-" + rev[16...19] + "-" + rev[20...31]
        return finalString
    }
    
    class var sharedInstance: BLEMingle {
        struct Static {
            static let instance: BLEMingle = BLEMingle()
        }
        return Static.instance
    }
    
    func sendDataToPeripheral(data: NSData) {
        dataToSend = data
        peripheralManager.stopAdvertising()
        startAdvertisingToPeripheral()
    }

    func sendPart() {
        var piece:String = datastring
        peripheralManager.stopAdvertising()
        let part:String = count(piece) > 14 ? piece[0...14] + "-" : piece[0...count(piece)-1] + " "
        if (count(piece) > 15)
        {
            piece = piece[15...count(piece)-1]
        }
        let messageUUID = StringToUUID(part)
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
        datastring = piece
    }

    func delay(delay:Double, closure:()->()) {
        dispatch_after( dispatch_time( DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)) ), dispatch_get_main_queue(), closure)
    }
    
    func startAdvertisingToPeripheral() {
        var allTime:UInt64 = 0;
        if (dataToSend != nil)
        {
            datastring = NSString(data:dataToSend, encoding:NSUTF8StringEncoding) as! String
            datastring = "iPhone: " + datastring
            if (count(datastring) > 15)
            {
                for (var i:Double = 0; i < Double(count(datastring))/15.000; i++)
                {
                    let delay = i/10.000 * Double(NSEC_PER_SEC)
                    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                    allTime = time
                    dispatch_after(time, dispatch_get_main_queue(), { () -> Void in self.sendPart() });
                }
            }
            else
            {
                let messageUUID = StringToUUID(datastring)
                if !peripheralManager.isAdvertising {
                    peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
                }
            }
        }
    }
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        
        if peripheral.state != CBPeripheralManagerState.PoweredOn {
            return
        }
        
        print("self.peripheralManager powered on.")
        
        transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TRANSFER_CHARACTERISTIC_UUID), properties: CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Readable)
        
        let transferService = CBMutableService(type: CBUUID(string: TRANSFER_SERVICE_UUID), primary: true)
        
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager.addService(transferService)

    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        
        print("Central subscribed to characteristic: \(characteristic)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        
        print("Central unsubscribed from characteristic")
    }
    
    func transferData() {
        if sendingEOM {
            
            var didSend:Bool = peripheralManager.updateValue("EOM".dataUsingEncoding(NSUTF8StringEncoding), forCharacteristic: transferCharacteristic, onSubscribedCentrals: nil)
            
            if didSend {
                
                sendingEOM = false
                print("sending EOM")
                //sleep(10000)
                peripheralManager.stopAdvertising()
            }
            
            return
        }
        
        if sendDataIndex >= dataToSend.length {
            return
        }
        
        var didSend:Bool = true
        
        while(didSend) {
            var amountToSend:Int = dataToSend.length - sendDataIndex
            
            if amountToSend > MAX_TRANSFER_DATA_LENGTH {
                amountToSend = MAX_TRANSFER_DATA_LENGTH
            }
            
            var chunk = NSData(bytes: dataToSend.bytes + sendDataIndex, length: amountToSend)
            print("chunk: \(NSString(data: chunk, encoding: NSUTF8StringEncoding)!)")
            
            didSend = peripheralManager.updateValue(chunk, forCharacteristic: transferCharacteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                print("didnotsend")
                return;
            }
            
            var stringFromData = NSString(data: chunk, encoding: NSUTF8StringEncoding)
            print("Sent: " + (stringFromData! as String))
            
            sendDataIndex = sendDataIndex + amountToSend
            
            if sendDataIndex >= dataToSend.length {
                sendingEOM = true
                
                var eomSent = peripheralManager.updateValue("EOM".dataUsingEncoding(NSUTF8StringEncoding), forCharacteristic: transferCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    sendingEOM = false
                    print("Sending EOM")
                }
                
                return
            }
        }
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        print("Ready to transfer")
        transferData()
    }
}