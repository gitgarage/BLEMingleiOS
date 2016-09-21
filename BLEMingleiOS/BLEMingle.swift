import Foundation
import CoreBluetooth

extension String {
    subscript  (r: Range<Int>) -> String {
        get {
            let myNSString = self as NSString
            let start = r.lowerBound
            let length = r.upperBound - start + 1
            return myNSString.substring(with: NSRange(location: start, length: length))
        }
    }
    
    func dataFromHexadecimalString() -> NSData? {
        let myNSString = self as NSString
        let midString = myNSString.trimmingCharacters(in: NSCharacterSet(charactersIn: "<> ") as CharacterSet) as NSString
        let trimmedString = midString.replacingOccurrences(of: " ", with: "")
        
        // make sure the cleaned up string consists solely of hex digits, and that we have even number of them
        
        let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$",
                                             options: [.caseInsensitive])
        
        let this_max = trimmedString.characters.count
        let found = regex.firstMatch(in: trimmedString, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, this_max))
        if found == nil || found?.range.location == NSNotFound || this_max % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData
        
        let data = NSMutableData(capacity: this_max / 2)
        
        for i in 0 ..< 9999 {
            let lower = i * 2
            let upper = lower + 2
            let byteString = trimmedString[lower..<upper]
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data?.append([num] as [UInt8], length: 1)
            if (trimmedString[lower+2..<upper+2].characters.count<2)
            {
                break;
            }
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
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
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
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!){
        
        delegate?.didDiscoverPeripheral(peripheral)
        let splitUp : [String] = "\(advertisementData)".components(separatedBy: "\n")
        if (splitUp.count > 1)
        {
            var chop = splitUp[1]
            var counter = chop.characters.count - 2
            chop = chop[0..<counter]
            let chopSplit : [String] = "\(chop)".components(separatedBy: "\"")
            
            if !(chopSplit.count > 1 && chopSplit[1] == "Device Information")
            {
                var hexString = chop[4..<7] + chop[12..<19] + chop[21..<26]
                var datas = hexString.dataFromHexadecimalString()
                var string = NSString(data: datas! as Data, encoding: String.Encoding.utf8.rawValue) as String?
                if (string == nil) {
                } else if (!usedList.contains(string!))
                {
                    usedList.append(string!)
                    let this_count = string!.characters.count
                    if (this_count == 9 && string![this_count-1..<this_count-1] == "-")
                    {
                        finalString = finalString + string![0..<this_count-2]
                    }
                    else
                    {
                        lastString = finalString + string! + "\n" as NSString!
                        print(lastString)
                        finalString = ""
                        usedList = newList
                        usedList.append(string!)
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
            peripheral.discoverCharacteristics([CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)], for: service )
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        print("didDiscoverCharacteristicsForService: \(service)")
        
        for characteristic in service.characteristics ?? [] {
            if ((characteristic ).uuid.isEqual(CBUUID(string: TRANSFER_CHARACTERISTIC_UUID))) {
                print("Discovered characteristic: \(characteristic)")
                peripheral .setNotifyValue(true, for: characteristic )
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            return
        }
        
        var stringFromData = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue)
        
        if (stringFromData! == "EOM") {
            print("Data Received: \(NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue))")
            data.length = 0
            //            peripheral.setNotifyValue(false, forCharacteristic: characteristic)
            //            centralManager.cancelPeripheralConnection(peripheral)
        }
        else {
            data.append(characteristic.value!)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error != nil {
            return
        }
        
        if !characteristic.uuid.isEqual(CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)) {
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
        var rev = String(hex.characters.reversed())
        let hexData: NSData! = rev.data(using: String.Encoding.utf8, allowLossyConversion: false) as NSData!
        rev = hexData.toHexString()
        while(rev.characters.count < 32) {
            rev = "0" + rev;
        }
        rev = rev[0..<31]
        let finalString = rev[0..<7] + "-" + rev[8..<11] + "-" + rev[12..<15] + "-" + rev[16..<19] + "-" + rev[20..<31]
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
        let bingo = piece.characters.count
        let part:String = bingo > 14 ? piece[0..<14] + "-" : piece[0..<bingo-1] + " "
        if (piece.characters.count > 15)
        {
            piece = piece[15..<piece.characters.count-1]
        }
        let messageUUID = StringToUUID(hex: part)
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
        datastring = piece
    }
    
    func startAdvertisingToPeripheral() {
        var allTime:DispatchTime = DispatchTime.now();
        if (dataToSend != nil)
        {
            datastring = NSString(data:dataToSend as Data, encoding:String.Encoding.utf8.rawValue) as! String
            datastring = "iPhone: " + datastring
            if (datastring.characters.count > 15)
            {
                for j in 0 ..< datastring.characters.count/15 {
                    let i = Double(j)
                    let delay = i/10.000 * Double(NSEC_PER_SEC)
                    
                    let when = DispatchTime.now() + delay
                    allTime = when
                    DispatchQueue.main.asyncAfter(deadline: when){
                        () -> Void in self.sendPart();
                    }
                }
            }
            else
            {
                let messageUUID = StringToUUID(hex: datastring)
                if !peripheralManager.isAdvertising {
                    peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
                }
            }
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        if #available(iOS 10.0, *) {
            if peripheral.state != CBManagerState.poweredOn {
                return
            }
        } else {
            // Fallback on earlier versions
        }
        
        print("self.peripheralManager powered on.")
        
        transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TRANSFER_CHARACTERISTIC_UUID), properties: CBCharacteristicProperties.notify, value: nil, permissions: CBAttributePermissions.readable)
        
        let transferService = CBMutableService(type: CBUUID(string: TRANSFER_SERVICE_UUID), primary: true)
        
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager.add(transferService)
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        
        print("Central subscribed to characteristic: \(characteristic)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        
        print("Central unsubscribed from characteristic")
    }
    
    func transferData() {
        if sendingEOM {
            
            var didSend:Bool = peripheralManager.updateValue("EOM".data(using: String.Encoding.utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            
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
            print("chunk: \(NSString(data: chunk as Data, encoding: String.Encoding.utf8.rawValue)!)")
            
            didSend = peripheralManager.updateValue(chunk as Data, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                print("didnotsend")
                return;
            }
            
            var stringFromData = NSString(data: chunk as Data, encoding: String.Encoding.utf8.rawValue)
            print("Sent: " + (stringFromData! as String))
            
            sendDataIndex = sendDataIndex + amountToSend
            
            if sendDataIndex >= dataToSend.length {
                sendingEOM = true
                
                let eomSent = peripheralManager.updateValue("EOM".data(using: String.Encoding.utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
                
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
