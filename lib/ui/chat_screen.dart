import 'dart:io';

import 'package:chatfirebase/ui/chat_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:chatfirebase/ui/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ChatScreen extends StatefulWidget {
	@override
	_ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
	final GoogleSignIn login = GoogleSignIn();
	final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

	bool _isLoading = false;
	FirebaseUser _currentUser;

	Future<FirebaseUser> _getUser() async {
		if (this._currentUser != null) {
			return this._currentUser;
		}

		try {
			final GoogleSignInAccount googleSignInAccount = await this.login.signIn();
			final GoogleSignInAuthentication googleSignInAuthentication =
			await googleSignInAccount.authentication;

			final AuthCredential authCredential = GoogleAuthProvider.getCredential(
				idToken: googleSignInAuthentication.idToken,
				accessToken: googleSignInAuthentication.idToken);

			final AuthResult authResult =
			await FirebaseAuth.instance.signInWithCredential(authCredential);

			return authResult.user;
		} catch (e) {
			return null;
		}
	}

	@override
	void initState() {
		super.initState();

		FirebaseAuth.instance.onAuthStateChanged.listen((user) {
			setState(() {
				this._currentUser = user;
			});
		});
	}

	void _sendMessage({String text, File imgFile}) async {
		final FirebaseUser user = await this._getUser();

		if (user == null) {
			this._scaffoldKey.currentState.showSnackBar(SnackBar(
				content: Text('Não foi possível fazer o login, tente novamente!'),
				backgroundColor: Colors.red,
				));
		} else {
			final FirebaseUser user = await this._getUser();

			Map<String, dynamic> data = {
				'uid': user.uid,
				'senderName': user.displayName,
				'senderPhotoUrl': user.photoUrl,
				'time': Timestamp.now()
			};

			if (imgFile != null) {
				setState(() {
					this._isLoading = true;
				});
				StorageUploadTask task = FirebaseStorage.instance
					.ref()
					.child('chat-images')
					.child(DateTime
							   .now()
							   .millisecondsSinceEpoch
							   .toString())
					.putFile(imgFile);

				StorageTaskSnapshot taskSnapshot = await task.onComplete;
				String url = await taskSnapshot.ref.getDownloadURL();

				data['imgUrl'] = url;
				setState(() {
					this._isLoading = false;
				});
			}

			if (text != null) {
				data['text'] = text;
			}

			Firestore.instance.collection('messages').document().setData(data);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			key: this._scaffoldKey,
			appBar: AppBar(
				centerTitle: this._currentUser == null,
				title: Text(this._currentUser != null
								? 'Olá, ${this._currentUser.displayName}'
								: 'Chat '
					'App'),
				elevation: 0,
				actions: <Widget>[
					this._currentUser != null
						? IconButton(
						icon: Icon(Icons.exit_to_app),
						onPressed: () async {
							await FirebaseAuth.instance.signOut();
							await this.login.signOut();

							this._scaffoldKey.currentState.showSnackBar(SnackBar(
								content: Text('Você saiu com sucesso!'),
								));
						},
						)
						: Container()
				],
				),
			body: Column(
				children: <Widget>[
					Expanded(
						child: StreamBuilder<QuerySnapshot>(
							stream: Firestore.instance.collection('messages')
								.orderBy('time')
								.snapshots(),
							builder: (BuildContext context, snapshot) {
								switch (snapshot.connectionState) {
									case ConnectionState.none:
									case ConnectionState.waiting:
										return CircularProgressIndicator();
									default:
										List<DocumentSnapshot> documents = snapshot.data.documents
											.reversed.toList();

										return ListView.builder(
											itemBuilder: (BuildContext context, int index) {
												return ChatMessage(documents[index].data,
																	   documents[index]
																		   .data['uid'] == this
																		   ._currentUser?.uid);
											},
											itemCount: documents.length,
											reverse: true);
								}
							}),
						),
					this._isLoading ? LinearProgressIndicator() : Container(),
					TextComposer(this._sendMessage)
				],
				),
			);
	}
}
