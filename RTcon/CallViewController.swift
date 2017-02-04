//
//  CallViewController.swift
//  RTcon
//
//  Created by 下地勇人 on 2016/12/04.
//  Copyright © 2016年 下地勇人. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import ReachabilitySwift

class CallViewController: UIViewController {
    var btConnection: BluetoothConnection? = nil
    weak var callback: UIViewController?
    let reachability = Reachability()!
    
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var callButton: UIButton!
    
    fileprivate var _peer: SKWPeer?
    fileprivate var _msLocal: SKWMediaStream?
    fileprivate var _msRemote: SKWMediaStream?
    fileprivate var _mediaConnection: SKWMediaConnection?
    fileprivate var _id: String? = nil
    fileprivate var _bEstablished: Bool = false
    fileprivate var _listPeerIds: Array<String> = []
    fileprivate var _data: SKWDataConnection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        self.callButton.isEnabled = false
        
        if nil != self.navigationController {
            self.navigationController?.delegate = self
        }
        
        // サーバへ接続
        // APIキー、ドメインを設定
        let option: SKWPeerOption = SKWPeerOption.init()
        option.key = "1bb5e4fc-4f56-4ee0-89dc-f36ec07aa7e5"
        option.domain = "localhost"
        
        // Peerオブジェクトのインスタンスを生成
        _peer = SKWPeer.init(options: option)
        
        // コールバックを登録 (ERROR / 接続失敗時)
        _peer?.on(.PEER_EVENT_ERROR, callback: { (obj: NSObject?) in
            let error: SKWPeerError = obj as! SKWPeerError
            let alert: UIAlertController = UIAlertController.init(title: "Peer Error (\(error.type.rawValue))", message: "\(error.message)", preferredStyle: .alert)
            
            let defaultAction: UIAlertAction = UIAlertAction.init(title: "OK", style: .default, handler: nil)
            alert.addAction(defaultAction)
            
            self.present(alert, animated: true, completion: nil)
        })
        
        // コールバックを登録 (OPEN / 接続成功時)
        _peer?.on(.PEER_EVENT_OPEN, callback: { (obj: NSObject?) in
            self._id = obj as? String
            DispatchQueue.main.async {
                self.idLabel.text = "your ID: \(self._id!)"
                self.callButton.isEnabled = true
            }
        })
        
        // メディアを取得
        SKWNavigator.initialize(_peer)
        let constraints:SKWMediaConstraints = SKWMediaConstraints.init()
        _msLocal = SKWNavigator.getUserMedia(constraints) as SKWMediaStream
        
        // ローカルビデオメディアをセット
        let localVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_LOCAL_VIDEO.hashValue) as! SKWVideo
        localVideoView.addSrc(_msLocal, track: 0)
        
        // コールバックを登録（CALL / 相手から着信時)
        _peer?.on(.PEER_EVENT_CALL, callback: { (obj: NSObject?) in
            self._mediaConnection = obj as? SKWMediaConnection
            self._mediaConnection?.answer(self._msLocal);
            self._bEstablished = true
            self.updateUI()
        })
        
        // コールバックを登録（CONNECTION / 相手からデータ通信開始時)
        _peer?.on(.PEER_EVENT_CONNECTION, callback: { (obj: NSObject?) in
            self._data = obj as? SKWDataConnection
            self.setDataCallbacks(self._data!)
            self.btConnection?.read(callback: { (message: String) in
                self.send(message)
            })
            self.updateUI()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        /*NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: ReachabilityChangedNotification, object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("Could not start reachability notifier")
        }*/
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Backボタン押下時
    @IBAction func onBack(_ sender: UIButton) {
        btConnection?.disconnect()
        
        if self._mediaConnection != nil {
            self.performSelector(inBackground: #selector(CallViewController.hangUp), with: nil)
        }
        
        if _data != nil {
            self.performSelector(inBackground: #selector(CallViewController.disconnect), with: nil)
        }
        
        if _peer != nil {
            _peer?.disconnect()
        }
        
        let _ = self.navigationController?.popToRootViewController(animated: true)
    }
    
    // Call ボタン押下時
    @IBAction func pushCallButton(_ sender: AnyObject) {
        if self._mediaConnection == nil {
            self.getPeerList()
        }else{
            self.performSelector(inBackground: #selector(CallViewController.hangUp), with: nil)
        }
        
        if _data == nil {
            self.getPeerList()
        }else{
            self.performSelector(inBackground: #selector(CallViewController.disconnect), with: nil)
        }
    }
    
    // ネットワーク接続変化時
    func reachabilityChanged(note: NSNotification) {
        let reachability = note.object as! Reachability
        
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        } else {
            print("Network not reachable")
        }
        
        if self._peer != nil {
            _peer?.reconnect()
        }
    }
    
    func setMediaCallbacks(_ media:SKWMediaConnection){
        // コールバックを登録（Stream）
        media.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_STREAM, callback: { (obj:NSObject?) -> Void in
            self._msRemote = obj as? SKWMediaStream
            
            let session: AVAudioSession = AVAudioSession.sharedInstance()
            do {
                try session.overrideOutputAudioPort(.speaker)
            } catch {
                print("override output audio port error")
            }
            
            DispatchQueue.main.async {
                () -> Void in
                let remoteVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.isHidden = false
                remoteVideoView.addSrc(self._msRemote, track: 0)
            }
        })
        
        // コールバックを登録（Close）
        media.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_CLOSE, callback: { (obj:NSObject?) -> Void in
            self._msRemote = obj as? SKWMediaStream
            
            DispatchQueue.main.async {
                () -> Void in
                let remoteVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.removeSrc(self._msRemote, track: 0)
                self._msRemote = nil
                self._mediaConnection = nil
                self._bEstablished = false
                remoteVideoView.isHidden = true
            }
            
            self.updateUI()
        })
    }
    
    // data
    func setDataCallbacks(_ data:SKWDataConnection){
        // コールバックを登録(チャンネルOPEN)
        data.on(SKWDataConnectionEventEnum.DATACONNECTION_EVENT_OPEN, callback: { (obj:NSObject?) -> Void in
            print("[system] DataConnection opened")
            self._bEstablished = true;
        })
        
        // コールバックを登録(DATA受信)
        data.on(SKWDataConnectionEventEnum.DATACONNECTION_EVENT_DATA, callback: { (obj:NSObject?) -> Void in
            let strValue:String = obj as! String
            print("[Partner] \(strValue)")
            self.btConnection?.send(message: strValue)
        })
        
        // コールバックを登録(チャンネルCLOSE)
        data.on(SKWDataConnectionEventEnum.DATACONNECTION_EVENT_CLOSE, callback: { (obj:NSObject?) -> Void in
            self._data = nil
            self._bEstablished = false
            print("[system] DataConnection closed")
            self.updateUI()
        })
    }
    
    // 相手へのビデオ発信
    func getPeerList(){
        if (_peer == nil) || (_id == nil) || (_id?.characters.count == 0) {
            return
        }
        
        _peer?.listAllPeers({ (peers:[Any]?) -> Void in
            self._listPeerIds = []
            let peersArray:[String] = peers as! [String]
            for strValue:String in peersArray{
                print(strValue)
                
                if strValue == self._id{
                    continue
                }
                
                self._listPeerIds.append(strValue)
            }
            
            if self._listPeerIds.count >= 0{
                self.showPeerDialog()
            }
        })
    }
    
    // ビデオ通話を開始する
    func call(_ strDestId: String) {
        let option = SKWCallOption()
        _mediaConnection = _peer!.call(withId: strDestId, stream: _msLocal, options: option)
        if _mediaConnection != nil {
            self.setMediaCallbacks(self._mediaConnection!)
            _bEstablished = true
        }
        self.updateUI()
    }
    
    // ビデオ通話を終了する
    func hangUp(){
        if _mediaConnection != nil{
            if _msRemote != nil{
                let remoteVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                
                remoteVideoView.removeSrc(_msRemote, track: 0)
                _msRemote?.close()
                _msRemote = nil
            }
            _mediaConnection?.close()
        }
    }
    
    // データチャンネルを開く
    func connect(_ strDestId: String) {
        let options = SKWConnectOption()
        options.label = "chat"
        options.metadata = "{'message': 'hi'}"
        options.serialization = SKWSerializationEnum.SERIALIZATION_BINARY
        options.reliable = true
        
        // 接続
        _data = _peer?.connect(withId: strDestId, options: options)
        setDataCallbacks(self._data!)
        self.updateUI()
    }
    
    // 接続を終了する
    func disconnect(){
        if _bEstablished == false{
            return
        }
        _bEstablished = false
        
        if _data != nil {
            _data?.close()
        }
    }
    
    // テキストデータを送信する
    func send(_ data:String){
        let bResult:Bool = (_data?.send(data as NSObject!))!
        
        if bResult == true {
            print("[send] \(data)")
        }
    }
    
    // Peer の一覧（TableView）を表示
    func showPeerDialog(){
        let vc = PeerListViewController()
        vc.items = _listPeerIds as [AnyObject]?
        vc.callback = self
        
        let nc = UINavigationController.init(rootViewController: vc)
        
        DispatchQueue.main.async(execute: {
            self.present(nc, animated: true, completion: nil)
        })
        
        //performSegue(withIdentifier: "showPeerList", sender: self)
    }
    
    // UIのセットアップ
    func setupUI(){
        let rcScreen:CGRect = self.view.bounds;
        
        
        //ローカルビデオ用のView
        var rcLocal:CGRect = CGRect.zero;
        rcLocal.size.width = rcScreen.size.height / 5;
        rcLocal.size.height = rcLocal.size.width;
        
        rcLocal.origin.x = rcScreen.size.width - rcLocal.size.width - 8.0;
        rcLocal.origin.y = rcScreen.size.height - rcLocal.size.height - 8.0;
        rcLocal.origin.y -= (self.navigationController?.toolbar.frame.size.height)!
        
        
        let vwVideo:SKWVideo = SKWVideo.init(frame: rcLocal)
        vwVideo.tag = ViewTag.tag_LOCAL_VIDEO.hashValue
        self.view.addSubview(vwVideo)
        
        
        //リモートビデオ用のView
        var rcRemote:CGRect = CGRect.zero;
        rcRemote.size.width = rcScreen.size.width;
        rcRemote.size.height = rcRemote.size.width;
        
        rcRemote.origin.x = (rcScreen.size.width - rcRemote.size.width) / 2.0;
        rcRemote.origin.y = (rcScreen.size.height - rcRemote.size.height) / 2.0;
        rcRemote.origin.y -= 8.0;
        
        //Remote SKWVideo
        let vwRemote:SKWVideo = SKWVideo.init(frame: rcRemote)
        vwRemote.tag = ViewTag.tag_LOCAL_VIDEO.hashValue
        vwRemote.isHidden = true
        self.view.addSubview(vwVideo)
        vwRemote.tag = ViewTag.tag_REMOTE_VIDEO.hashValue
        vwRemote.isHidden = true
        self.view.addSubview(vwRemote)
        
        self.updateUI();
    }
    
    func updateUI(){
        DispatchQueue.main.async { () -> Void in
            //CALLボタンのアップデート
            if self._bEstablished == false{
                self.callButton.titleLabel?.text = "Call"
            }else{
                self.callButton.titleLabel?.text = "Hang up"
            }
            
            //IDラベルのアップデート
            if self._id == nil{
                self.idLabel.text = "your Id:"
            }else{
                self.idLabel.text = "your Id:"+self._id! as String
            }
        }
    }
    
    enum ViewTag : UInt {
        case tag_ID = 1000
        case tag_WEBRTC_ACTION
        case tag_REMOTE_VIDEO
        case tag_LOCAL_VIDEO
    }
    
    /*
    func appendLogWithMessage(_ strMessage:String){
        print("message: \(strMessage)")
    }
    */
    
    /*
    func appendLogWithHead(_ strHeader: String?, value strValue: String) {
        if 0 == strValue.characters.count {
            return
        }
        let mstrValue = NSMutableString()
        if nil != strHeader {
            mstrValue.append("[")
            mstrValue.append(strHeader!)
            mstrValue.append("] ")
        }
        if 32000 < strValue.characters.count {
            //            var rng:NSRange = NSMakeRange(0, 32)
            mstrValue.append(strValue.substring(with: (strValue.characters.index(strValue.startIndex, offsetBy: 0) ..< strValue.characters.index(strValue.startIndex, offsetBy: 32))))
            mstrValue.append("...")
            //            rng = NSMakeRange(strValue.characters.count - 32, 32)
            mstrValue.append(strValue.substring(with: (strValue.characters.index(strValue.startIndex, offsetBy: strValue.characters.count - 32) ..< strValue.characters.index(strValue.startIndex, offsetBy: 32))))
        } else {
            mstrValue.append(strValue)
        }
        mstrValue.append("\n")
        self.performSelector(onMainThread: #selector(CallViewController.appendLogWithMessage(_:)), with: mstrValue, waitUntilDone: true)
    }
    */
    
    /*
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPeerList" {
            let vc: PeerListViewController = segue.destination as! PeerListViewController
            vc.items = _listPeerIds as [AnyObject]?
            vc.callback = self
        }
    }
    */
}

extension CallViewController: UINavigationControllerDelegate, UIAlertViewDelegate {
}
