import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITextViewDelegate {

    @IBOutlet var textView: UITextView!
    var bleCentral: BLECentral!

    @IBAction func sendData(sender: UIButton) {
        var dataToSend = textView.text.dataUsingEncoding(NSUTF8StringEncoding)

        bleCentral.sendDataToPeripheral(dataToSend!)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bleCentral = BLECentral()
        textView.delegate = self
    }

    override func viewDidAppear(animated: Bool) {
        bleCentral.startAdvertisingToPeripheral()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
    }
}
