import Foundation
import CoreBluetooth

extension String {
    subscript(r: Range<Int>) -> String {
        get {
            let startIndex = advance(self.startIndex, r.startIndex)
            let endIndex = advance(self.startIndex, r.endIndex-1)

            return self[Range(start: startIndex, end: endIndex)]
        }
    }

    var length: Int {
        let characters = Array(self)
        return characters.count
    }
}

extension NSData {
    func toHexString() -> String {

        var string = NSMutableString(capacity: length * 2)
        var byte: UInt8 = 0

        for i in 0 ..< length {
            getBytes(&byte, range: NSMakeRange(i, 1))
            string.appendFormat("%02x", byte)
        }

        return string as String
    }
}

class BLECentral: NSObject, CBPeripheralManagerDelegate {

    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic!
    var dataToSend: NSData!
    var sendDataIndex: Int!
    var datastring: String!
    var sendingEOM: Bool = false
    let MAX_TRANSFER_DATA_LENGTH: Int = 20
    let TRANSFER_SERVICE_UUID:String = "E20A39F4-73F5-4BC4-A12F-17D1AD07A961"
    let TRANSFER_CHARACTERISTIC_UUID:String = "08590F7E-DB05-467E-8757-72F6FAEB13D4"

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func StringToUUID(hex: String) -> String
    {
        var rev = String(reverse(hex))
        var hexData: NSData! = rev.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        rev = hexData.toHexString()
        while(countElements(rev) < 32) {
            rev = "0" + rev;
        }
        rev = rev[0...32]
        var finalString = rev[0...8] + "-" + rev[8...12] + "-" + rev[12...16] + "-" + rev[16...20] + "-" + rev[20...32]
        return finalString
    }
    
    class var sharedInstance: BLECentral {
        struct Static {
            static let instance: BLECentral = BLECentral()
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
        var part: String = piece.length > 14 ? piece[0...15] + "-" : piece[0...piece.length] + " "
        if (piece.length > 15)
        {
            piece = piece[15...piece.length]
        }
        var messageUUID = StringToUUID(part)
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
        datastring = piece
    }

    func delay(delay:Double, closure:()->()) {
        dispatch_after( dispatch_time( DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)) ), dispatch_get_main_queue(), closure)
    }
    
    func startAdvertisingToPeripheral() {
        if (dataToSend != nil)
        {
            datastring = NSString(data:dataToSend, encoding:NSUTF8StringEncoding) as String
            if (datastring.length > 15)
            {
                for (var i:Double = 0; i < Double(datastring.length)/15.000; i++)
                {
                    let delay = i/10.000 * Double(NSEC_PER_SEC)
                    let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
                    dispatch_after(time, dispatch_get_main_queue(), { () -> Void in self.sendPart() });
                }
            }
            else
            {
                var messageUUID = StringToUUID(datastring)
                if !peripheralManager.isAdvertising {
                    peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: messageUUID)]])
                }
            }
        }
    }
    
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {
        
        if peripheral.state != CBPeripheralManagerState.PoweredOn {
            return
        }
        
        println("self.peripheralManager powered on.")
        
        transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TRANSFER_CHARACTERISTIC_UUID), properties: CBCharacteristicProperties.Notify, value: nil, permissions: CBAttributePermissions.Readable)
        
        var transferService = CBMutableService(type: CBUUID(string: TRANSFER_SERVICE_UUID), primary: true)
        
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager.addService(transferService)
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didSubscribeToCharacteristic characteristic: CBCharacteristic!) {
        
        println("Central subscribed to characteristic: \(characteristic)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic!) {
        
        println("Central unsubscribed from characteristic")
    }
    
    func transferData() {
        if sendingEOM {
            var didSend:Bool = peripheralManager.updateValue("EOM".dataUsingEncoding(NSUTF8StringEncoding), forCharacteristic: transferCharacteristic, onSubscribedCentrals: nil)
            
            if didSend {
                
                sendingEOM = false
                println("sending EOM")
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
            println("chunk: \(NSString(data: chunk, encoding: NSUTF8StringEncoding)!)")
            
            didSend = peripheralManager.updateValue(chunk, forCharacteristic: transferCharacteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                println("didnotsend")
                return;
            }
            
            var stringFromData = NSString(data: chunk, encoding: NSUTF8StringEncoding)
            println("Sent: " + stringFromData!)
            
            sendDataIndex = sendDataIndex + amountToSend
            
            if sendDataIndex >= dataToSend.length {
                sendingEOM = true
                
                var eomSent = peripheralManager.updateValue("EOM".dataUsingEncoding(NSUTF8StringEncoding), forCharacteristic: transferCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    sendingEOM = false
                    println("Sending EOM")
                }
                
                return
            }
        }
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager!) {
        println("Ready to transfer")
        transferData()
    }
}