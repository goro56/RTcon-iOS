//
//  SkywayConnection.swift
//  RTcon
//
//  Created by 下地勇人 on 2017/02/04.
//  Copyright © 2017年 下地勇人. All rights reserved.
//

import Foundation

class SkywayConnection: NSObject {
    var peer: SKWPeer?
    var id: String?
    var mediaConnection: SKWMediaConnection?
    var dataConnection: SKWDataConnection?
    
    override init() {
        // APIキー、ドメインを設定
        let option: SKWPeerOption = SKWPeerOption.init()
        option.key = "1bb5e4fc-4f56-4ee0-89dc-f36ec07aa7e5"
        option.domain = "localhost"
        
        // Peerオブジェクトのインスタンスを生成
        self.peer = SKWPeer.init(options: option)
        
        // コールバックを登録 (ERROR / 接続失敗時)
        self.peer?.on(.PEER_EVENT_ERROR, callback: { (obj: NSObject?) in
            let error: SKWPeerError = obj as! SKWPeerError
            print(error)
            /*let alert: UIAlertController = UIAlertController.init(title: "Peer Error (\(error.type.rawValue))", message: "\(error.message)", preferredStyle: .alert)
            
            let defaultAction: UIAlertAction = UIAlertAction.init(title: "OK", style: .default, handler: nil)
            alert.addAction(defaultAction)
            
            self.present(alert, animated: true, completion: nil)*/
        })
        
        // コールバックを登録 (OPEN / 接続成功時)
        self.peer?.on(.PEER_EVENT_OPEN, callback: { (obj: NSObject?) in
            self.id = obj as? String
            /*DispatchQueue.main.async {
                self.idLabel.text = "your ID: \(self._id!)"
                self.callButton.isEnabled = true
            }*/
        })
    }
    
    // コールバックを登録（CALL / 相手から着信時)
    func setMediaConnectionCallback(answer: SKWMediaStream, callback: @escaping (Void) -> Void) {
        self.peer?.on(.PEER_EVENT_CALL, callback: { (obj: NSObject?) in
            self.mediaConnection = obj as? SKWMediaConnection
            self.mediaConnection?.answer(answer)
            callback()
        })
    }
    
    // コールバックを登録（CONNECTION / 相手からデータ通信開始時)
    func setDataConnectionCallback(callback: @escaping (Void) -> Void) {
        self.peer?.on(.PEER_EVENT_CONNECTION, callback: { (obj: NSObject?) in
            self.dataConnection = obj as? SKWDataConnection
            //self.setDataCallbacks(self._data!)
            /*self.btConnection?.read(callback: { (message: String) in
                self.send(message)
            })*/
            callback()
        })
    }
    
    func setMediaCallbacks(){
        // コールバックを登録（Stream）
        mediaConnection.on(.MEDIACONNECTION_EVENT_STREAM, callback: { (obj: NSObject?) -> Void in
            self._msRemote = obj as? SKWMediaStream
            
            let session: AVAudioSession = AVAudioSession.sharedInstance()
            do {
                try session.overrideOutputAudioPort(.speaker)
            } catch {
                print("override output audio port error")
            }
            
            DispatchQueue.main.async {
                () -> Void in
                let remoteVideoView: SKWVideo = self.view.viewWithTag(ViewTag.tag_REMOTE_VIDEO.hashValue) as! SKWVideo
                remoteVideoView.isHidden = false
                remoteVideoView.addSrc(self._msRemote, track: 0)
            }
        })
        
        // コールバックを登録（Close）
        mediaConnection.on(.MEDIACONNECTION_EVENT_CLOSE, callback: { (obj: NSObject?) -> Void in
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
    
    func setDataCallbacks(){
        // コールバックを登録(チャンネルOPEN)
        dataConnection.on(.DATACONNECTION_EVENT_OPEN, callback: { (obj: NSObject?) -> Void in
            print("[system] DataConnection opened")
            self._bEstablished = true;
        })
        
        // コールバックを登録(DATA受信)
        dataConnection.on(.DATACONNECTION_EVENT_DATA, callback: { (obj: NSObject?) -> Void in
            let strValue:String = obj as! String
            print("[Partner] \(strValue)")
            self.btConnection?.send(message: strValue)
        })
        
        // コールバックを登録(チャンネルCLOSE)
        dataConnection.on(.DATACONNECTION_EVENT_CLOSE, callback: { (obj:NSObject?) -> Void in
            self._data = nil
            self._bEstablished = false
            print("[system] DataConnection closed")
            self.updateUI()
        })
    }

}
