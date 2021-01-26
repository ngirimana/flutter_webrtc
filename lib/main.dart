import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Webrtc Flutter'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  RTCPeerConnection _peerConnection;
  MediaStream _localStream;
  final _localRenderer = new RTCVideoRenderer();
  final _remoteRender = new RTCVideoRenderer();
  final sdpController = new TextEditingController();

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRender.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderes();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };
    _localStream = await _getUserMedia();
    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };
    pc.onIceConnectionState = (e) {
      print(e);
    };
    pc.onAddStream = (stream) {
      print('addStream:' + stream.id);
      _remoteRender.srcObject = stream;
    };
    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {'facingMode': 'user'}
    };
    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
    return stream;
  }

  initRenderes() async {
    await _localRenderer.initialize();
    await _remoteRender.initialize();
  }

  void _createOffer() async {
    RTCSessionDescription description =
        await _peerConnection.createOffer({'OfferToReceiveAudio': 1});
    var session = parse(description.sdp);
    print(json.encode(session));
    _offer = true;
    _peerConnection.setLocalDescription(description);
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    String sdp = write(session, null);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
        await _peerConnection.createAnswer({'OfferToReceiveAudio': 1});
    var session = parse(description.sdp);
    print(json.encode(session));
    _peerConnection.setLocalDescription(description);
  }

  void _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }

  SizedBox videoRenderer() => SizedBox(
        height: 210,
        child: Row(
          children: [
            Flexible(
              child: Container(
                key: Key('local'),
                margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                decoration: BoxDecoration(color: Colors.black),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                ),
              ),
            ),
            Flexible(
              child: Container(
                key: Key('remote'),
                margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                decoration: BoxDecoration(color: Colors.black),
                child: RTCVideoView(_remoteRender),
              ),
            ),
          ],
        ),
      );
  Row offerAndAnswerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          RaisedButton(
            onPressed: _createOffer,
            child: Text('Offer'),
            color: Colors.amber,
          ),
          RaisedButton(
            onPressed: _createAnswer,
            child: Text('Answer'),
            color: Colors.amber,
          )
        ],
      );
  Padding sdpCandidateTF() => Padding(
        padding: const EdgeInsets.all(10.0),
        child: TextField(
          controller: sdpController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          maxLength: TextField.noMaxLength,
        ),
      );
  Row sdpCandidateButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          RaisedButton(
            onPressed: _setRemoteDescription,
            child: Text('Set Remote Desc'),
            color: Colors.amber,
          ),
          RaisedButton(
            onPressed: _setCandidate,
            child: Text('Set Candidate'),
            color: Colors.amber,
          ),
        ],
      );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        child: Column(
          children: [
            videoRenderer(),
            offerAndAnswerButtons(),
            sdpCandidateTF(),
            sdpCandidateButtons(),
          ],
        ),
      ),
    );
  }
}
