import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITextViewDelegate {

    @IBOutlet var textView: UITextView!
    @IBOutlet var Abel: UISwitch!
    var bleMingle: BLEMingle!

    func toggleSwitch() {
        var lastMessage = ""
        var allText = ""
        bleMingle.startScan()
        let priority = DispatchQueue.GlobalQueuePriority.default
        DispatchQueue.global(priority: priority).async {
            while (true)
            {
                let temp:String = self.bleMingle.lastString as String
                if (temp != lastMessage && temp != "")
                {
                    DispatchQueue.main.async {
                        allText = allText + temp
                        self.updateView(allText)
                    }
                    lastMessage = temp
                }
            }
        }
    }

    @IBAction func sendData(_ sender: AnyObject) {
        let dataToSend = textView.text.data(using: String.Encoding.utf8)

        bleMingle.sendDataToPeripheral(data: dataToSend! as NSData)
        textView.text = ""
    }

    func updateView(_ message: String) {
        let textView2 = self.view.viewWithTag(2) as! UITextView
        textView2.text = message
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bleMingle = BLEMingle()
        textView.delegate = self

        let delay = 2.000 * Double(NSEC_PER_SEC)
        let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time, execute: { () -> Void in self.toggleSwitch() });

    }

    override func viewDidAppear(_ animated: Bool) {
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

//    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
//        self.view.endEditing(true)
//    }
}
