const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendChatNotification = functions.firestore
  .document('chat/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) {
      console.log('❌ Message data is empty');
      return null;
    }

    const senderId = (messageData.senderId || '').toString();
    if (!senderId) {
      console.log('❌ senderId is missing');
      return null;
    }
    console.log(`📤 Message created by sender: ${senderId}`);

    const chatId = context.params.chatId;
    const chatRef = admin.firestore().doc(`chat/${chatId}`);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      console.log(`❌ Chat document not found: ${chatId}`);
      return null;
    }

    const chatData = chatSnap.data();
    if (!chatData) {
      console.log(`❌ Chat data is null for: ${chatId}`);
      return null;
    }

    const clientId = (chatData.clientId || '').toString();
    const freelancerId = (chatData.freelancerId || '').toString();
    if (!clientId || !freelancerId) {
      console.log(`❌ Chat missing clientId or freelancerId. clientId=${clientId}, freelancerId=${freelancerId}`);
      return null;
    }
    console.log(`📋 Chat participants - clientId: ${clientId}, freelancerId: ${freelancerId}`);

    const receiverId = senderId === clientId ? freelancerId : clientId;
    console.log(`📨 Receiver calculation - senderId: ${senderId}, clientId: ${clientId}, receiverId: ${receiverId}`);
    if (!receiverId) {
      console.log('❌ receiverId is null');
      return null;
    }

    const receiverRef = admin.firestore().doc(`users/${receiverId}`);
    const receiverSnap = await receiverRef.get();
    if (!receiverSnap.exists) {
      console.log(`❌ Receiver document NOT found: users/${receiverId}`);
      return null;
    }
    console.log(`✅ Receiver document found: ${receiverId}`);

    const receiverData = receiverSnap.data();
    const fcmToken = receiverData?.fcmToken;
    if (!fcmToken) {
      console.log(`❌ NO fcmToken for receiver ${receiverId}. Available fields: ${Object.keys(receiverData || {})}`);
      return null;
    }
    if (typeof fcmToken !== 'string') {
      console.log(`❌ fcmToken is invalid type '${typeof fcmToken}' for receiver ${receiverId}`);
      return null;
    }
    console.log(`🔑 FCM Token ready: ${fcmToken.substring(0, 30)}...`);

    const senderRef = admin.firestore().doc(`users/${senderId}`);
    const senderSnap = await senderRef.get();
    let senderName = 'New message';
    if (senderSnap.exists) {
      const senderData = senderSnap.data();
      const firstName = (senderData?.firstName || '').toString().trim();
      const lastName = (senderData?.lastName || '').toString().trim();
      // For RTL text (Arabic), don't add space - just concatenate
      // RTL text should be handled natively by the system
      const nameParts = [firstName, lastName].filter((part) => part.length > 0);
      senderName = nameParts.join(' ').trim() || 'New message';
      console.log(`👤 Sender name: ${senderName}`);
    } else {
      console.log(`⚠️  Sender document not found: ${senderId}`);
    }

    const text = (messageData.text || '').toString().trim();
    const type = (messageData.type || 'text').toString();

    let body = 'Sent a new message.';
    if (text.length > 0) {
      body = text;
    } else if (type === 'image') {
      body = 'Sent you a photo.';
    } else if (type === 'mixed') {
      body = 'Sent you a photo and message.';
    }

    const payload = {
      token: fcmToken,
      notification: {
        title: senderName,
        body,
      },
      data: {
        chatId,
        senderId,
        receiverId,
        messageId: context.params.messageId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_notifications',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log(`✅ Notification sent successfully to ${receiverId}. Response: ${response}`);
    } catch (error) {
      console.error(`❌ FAILED to send to ${receiverId}: ${error.code} - ${error.message}`);
    }

    return null;
  });
