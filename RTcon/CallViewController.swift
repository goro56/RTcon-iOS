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
    
    var peer: SKWPeer?
    var localMedia: SKWMediaStream?
    var remoteMedia: SKWMediaStream?
    var mediaConnection: SKWMediaConnection?
    var id: String? = nil
    var peerIds: Array<String> = []
    var dataConnection: SKWDataConnection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        callButton.isEnabled = false
        
        navigationController?.delegate = self
        
        // サーバへ接続
        // APIキー、ドメインを設定
        let option: SKWPeerOption = SKWPeerOption.init()
        option.key = "1bb5e4fc-4f56-4ee0-89dc-f36ec07aa7e5"
        option.domain = "localhost"
        
        // Peerオブジェクトのインスタンスを生成
        peer = SKWPeer.init(options: option)
        
        // コールバックを登録 (ERROR / 接続失敗時)
        peer?.on(.PEER_EVENT_ERROR, callback: { (obj: NSObject?) in
            let error: SKWPeerError = obj as! SKWPeerError
            
            let alert: UIAlertController = UIAlertController.init(title: "Peer Error (\(error.type.rawValue))", message: "\(error.message)", preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
            
            self.present(alert, animated: true, completion: nil)
        })
        
        // コールバックを登録 (OPEN / 接続成功時)
        peer?.on(.PEER_EVENT_OPEN, callback: { (obj: NSObject?) in
            self.id = obj as? String
            DispatchQueue.main.async {
                self.idLabel.text = "your ID: \(self.id)"
                self.callButton.isEnabled = true
            }
        })
        
        // メディアを取得
        SKWNavigator.initialize(peer)
        
        let constraints: SKWMediaConstraints = SKWMediaConstraints.init()
        constraints.cameraPosition = .CAMERA_POSITION_FRONT
        localMedia = SKWNavigator.getUserMedia(constraints) as SKWMediaStream
        
        // コールバックを登録（CALL / 相手から着信時)
        peer?.on(.PEER_EVENT_CALL, callback: { (obj: NSObject?) in
            self.mediaConnection = obj as? SKWMediaConnection
            self.mediaConnection?.answer(self.localMedia)
            self.setMediaCallbacks()
            self.updateUI()
        })
        
        // コールバックを登録（CONNECTION / 相手からデータ通信開始時)
        peer?.on(.PEER_EVENT_CONNECTION, callback: { (obj: NSObject?) in
            self.dataConnection = obj as? SKWDataConnection
            self.setDataCallbacks()
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
        
        if mediaConnection != nil {
            performSelector(inBackground: #selector(CallViewController.hangUp), with: nil)
        }
        
        if dataConnection != nil {
            performSelector(inBackground: #selector(CallViewController.disconnect), with: nil)
        }
        
        peer?.disconnect()
        
        let _ = navigationController?.popToRootViewController(animated: true)
    }
    
    // Call ボタン押下時
    @IBAction func pushCallButton(_ sender: AnyObject) {
        if mediaConnection == nil {
            getPeerList()
        } else {
            performSelector(inBackground: #selector(CallViewController.hangUp), with: nil)
        }
        
        if dataConnection != nil {
            performSelector(inBackground: #selector(CallViewController.disconnect), with: nil)
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
        
        peer?.reconnect()
    }
    
    func setMediaCallbacks(){
        // コールバックを登録（Stream）
        mediaConnection?.on(.MEDIACONNECTION_EVENT_STREAM, callback: { (obj: NSObject?) -> Void in
            self.remoteMedia = obj as? SKWMediaStream
            
            let session: AVAudioSession = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.defaultToSpeaker, .allowBluetooth])
            } catch {
                print("set audio category error")
            }
            
            DispatchQueue.main.async { () -> Void in
                let remoteVideoView: SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.isHidden = false
                remoteVideoView.addSrc(self.remoteMedia, track: 0)
            }
        })
        
        // コールバックを登録（Close）
        mediaConnection?.on(.MEDIACONNECTION_EVENT_CLOSE, callback: { (obj: NSObject?) -> Void in
            self.remoteMedia = obj as? SKWMediaStream
            
            DispatchQueue.main.async { () -> Void in
                let remoteVideoView:SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.removeSrc(self.remoteMedia, track: 0)
                self.remoteMedia = nil
                self.mediaConnection = nil
                remoteVideoView.isHidden = true
            }
            
            self.updateUI()
        })
    }
    
    func setDataCallbacks(){
        // コールバックを登録(チャンネルOPEN)
        dataConnection?.on(.DATACONNECTION_EVENT_OPEN, callback: { (obj: NSObject?) -> Void in
            print("[system] DataConnection opened")
        })
        
        // コールバックを登録(DATA受信)
        dataConnection?.on(.DATACONNECTION_EVENT_DATA, callback: { (obj: NSObject?) -> Void in
            let strValue:String = obj as! String
            print("[Partner] \(strValue)")
            self.btConnection?.send(message: strValue)
        })
        
        // コールバックを登録(チャンネルCLOSE)
        dataConnection?.on(.DATACONNECTION_EVENT_CLOSE, callback: { (obj: NSObject?) -> Void in
            self.dataConnection = nil
            print("[system] DataConnection closed")
            self.updateUI()
        })
        
        btConnection?.read(callback: { (message: String) in
            self.send(message)
        })
    }
    
    // ビデオ通話を開始する
    func call(destId: String) {
        let option = SKWCallOption()
        mediaConnection = peer?.call(withId: destId, stream: localMedia, options: option)
        setMediaCallbacks()
        updateUI()
    }
    
    // ビデオ通話を終了する
    func hangUp(){
        if let remoteMedia = remoteMedia {
            let remoteVideoView: SKWVideo = view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
            remoteVideoView.removeSrc(remoteMedia, track: 0)
            remoteMedia.close()
        }
        remoteMedia = nil
        mediaConnection?.close()
        updateUI()
    }
    
    // データチャンネルを開く
    func connect(destId: String) {
        let options = SKWConnectOption()
        options.reliable = true
        
        dataConnection = peer?.connect(withId: destId, options: options)
        setDataCallbacks()
    }
    
    // 接続を終了する
    func disconnect(){
        dataConnection?.close()
    }
    
    // テキストデータを送信する
    func send(_ data:String){
        if let dataConnection = dataConnection {
            let bResult = dataConnection.send(data as NSObject)
            if bResult {
                print("[send] \(data)")
            }
        }
    }
    
    // Peerリストを取得
    func getPeerList(){
        if (peer == nil) || (id == nil) || (id?.characters.count == 0) {
            return
        }
        
        peer?.listAllPeers({ (peers: [Any]?) -> Void in
            self.peerIds = []
            let peersArray: [String] = peers as! [String]
            for strValue: String in peersArray {
                if strValue != self.id {
                    self.peerIds.append(strValue)
                }
            }
            
            if self.peerIds.count >= 0 {
                self.showPeerDialog()
            }
        })
    }
    
    // Peer の一覧（TableView）を表示
    func showPeerDialog(){
        let vc = PeerListViewController()
        vc.items = peerIds as [AnyObject]?
        vc.callback = self
        
        let nc = UINavigationController.init(rootViewController: vc)
        
        DispatchQueue.main.async(execute: {
            self.present(nc, animated: true, completion: nil)
        })
    }
    
    // UIのセットアップ
    func setupUI(){
        let rcScreen: CGRect = view.bounds
        
        //ローカルビデオ用のView
        var rcLocal: CGRect = CGRect.zero
        rcLocal.size.width = rcScreen.size.height / 5
        rcLocal.size.height = rcLocal.size.width
        
        rcLocal.origin.x = rcScreen.size.width - rcLocal.size.width - 8.0
        rcLocal.origin.y = rcScreen.size.height - rcLocal.size.height - 8.0
        if let navigationController = navigationController {
            rcLocal.origin.y -= navigationController.toolbar.frame.size.height
        }
        
        let vwVideo: SKWVideo = SKWVideo.init(frame: rcLocal)
        vwVideo.tag = ViewTag.tag_LOCAL_VIDEO.hashValue
        vwVideo.isHidden = true
        view.addSubview(vwVideo)
        
        //リモートビデオ用のView
        var rcRemote: CGRect = CGRect.zero
        rcRemote.size.width = rcScreen.size.width
        rcRemote.size.height = rcRemote.size.width
        
        rcRemote.origin.x = (rcScreen.size.width - rcRemote.size.width) / 2.0
        rcRemote.origin.y = (rcScreen.size.height - rcRemote.size.height) / 2.0
        rcRemote.origin.y -= 8.0
        
        let vwRemote: SKWVideo = SKWVideo.init(frame: rcRemote)
        vwRemote.tag = ViewTag.tag_REMOTE_VIDEO.hashValue
        vwRemote.isHidden = true
        view.addSubview(vwRemote)
        
        updateUI()
    }
    
    func updateUI(){
        DispatchQueue.main.async { () -> Void in
            //CALLボタンのアップデート
            if self.mediaConnection == nil {
                self.callButton.titleLabel?.text = "Call"
            } else {
                self.callButton.titleLabel?.text = "Hang up"
            }
            
            //IDラベルのアップデート
            self.idLabel.text = "your Id: \(self.id)"
        }
    }
    
    enum ViewTag : UInt {
        case tagid = 1000
        case tag_WEBRTC_ACTION
        case tag_REMOTE_VIDEO
        case tag_LOCAL_VIDEO
    }
}

extension CallViewController: UINavigationControllerDelegate, UIAlertViewDelegate {
}
