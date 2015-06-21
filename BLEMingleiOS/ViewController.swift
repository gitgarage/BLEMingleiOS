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
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            while (true)
            {
                var temp:String = self.bleMingle.lastString as String
                if (temp != lastMessage && temp != "")
                {
                    dispatch_async(dispatch_get_main_queue()) {
                        allText = allText + temp
                        self.updateView(allText)
                    }
                    lastMessage = temp
                }
            }
        }
    }

    @IBAction func sendData(sender: AnyObject) {
        var dataToSend = textView.text.dataUsingEncoding(NSUTF8StringEncoding)

        bleMingle.sendDataToPeripheral(dataToSend!)
        textView.text = ""
    }

    func updateView(message: String) {
        var textView2 = self.view.viewWithTag(2) as UITextView
        textView2.text = message
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bleMingle = BLEMingle()
        textView.delegate = self

        let delay = 2.000 * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), { () -> Void in self.toggleSwitch() });

    }

    override func viewDidAppear(animated: Bool) {
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
    }
}
