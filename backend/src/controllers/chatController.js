const db = require('../config/database');
const path = require('path');

let messagesColumnsEnsured = false;

const ensureMessagesColumns = async () => {
  if (messagesColumnsEnsured) {
    return;
  }

  await db.query('ALTER TABLE messages ADD COLUMN IF NOT EXISTS image_url VARCHAR(500)');
  await db.query('ALTER TABLE messages ADD COLUMN IF NOT EXISTS audio_url VARCHAR(500)');
  messagesColumnsEnsured = true;
};

const getConversations = async (req, res, next) => {
  try {
    await ensureMessagesColumns();

    const userId = req.user.id;

    const result = await db.query(
      `SELECT c.*,
       CASE WHEN c.buyer_id = $1 THEN u2.first_name ELSE u1.first_name END as other_first_name,
       CASE WHEN c.buyer_id = $1 THEN u2.last_name ELSE u1.last_name END as other_last_name,
       CASE WHEN c.buyer_id = $1 THEN COALESCE(st.logo, u2.avatar) ELSE u1.avatar END as other_avatar,
       CASE WHEN c.buyer_id = $1 THEN st.logo ELSE NULL END as other_store_logo,
       CASE WHEN c.buyer_id = $1 THEN c.seller_id ELSE c.buyer_id END as other_user_id,
       CASE WHEN c.buyer_id = $1 THEN c.buyer_unread ELSE c.seller_unread END as unread_count,
       p.name as product_name
       FROM conversations c
       JOIN users u1 ON c.buyer_id = u1.id
       JOIN users u2 ON c.seller_id = u2.id
       LEFT JOIN LATERAL (
         SELECT s.logo
         FROM stores s
         WHERE s.user_id = c.seller_id AND s.is_active = true
         ORDER BY s.updated_at DESC NULLS LAST, s.created_at DESC
         LIMIT 1
       ) st ON true
       LEFT JOIN products p ON c.product_id = p.id
       WHERE c.buyer_id = $1 OR c.seller_id = $1
       ORDER BY c.last_message_at DESC NULLS LAST`,
      [userId]
    );

    res.json({ conversations: result.rows });
  } catch (err) {
    next(err);
  }
};

const getMessages = async (req, res, next) => {
  try {
    await ensureMessagesColumns();

    const { conversationId } = req.params;
    const userId = req.user.id;

    // Verify user is part of conversation
    const conv = await db.query(
      'SELECT * FROM conversations WHERE id = $1 AND (buyer_id = $2 OR seller_id = $2)',
      [conversationId, userId]
    );
    if (conv.rows.length === 0) {
      return res.status(404).json({ error: 'Conversation not found' });
    }

    // Mark messages as read
    const isBuyer = conv.rows[0].buyer_id === userId;
    if (isBuyer) {
      await db.query('UPDATE conversations SET buyer_unread = 0 WHERE id = $1', [conversationId]);
    } else {
      await db.query('UPDATE conversations SET seller_unread = 0 WHERE id = $1', [conversationId]);
    }
    await db.query(
      'UPDATE messages SET is_read = true, read_at = CURRENT_TIMESTAMP WHERE conversation_id = $1 AND sender_id != $2 AND is_read = false',
      [conversationId, userId]
    );

    const result = await db.query(
      `SELECT m.*, u.first_name, u.last_name, u.avatar
       FROM messages m
       JOIN users u ON m.sender_id = u.id
       WHERE m.conversation_id = $1
       ORDER BY m.created_at ASC`,
      [conversationId]
    );

    res.json({ messages: result.rows, conversation: conv.rows[0] });
  } catch (err) {
    next(err);
  }
};

const sendMessage = async (req, res, next) => {
  try {
    // Check if chat is enabled
    if (req.appSettings && (req.appSettings.chat_enabled === false || req.appSettings.chat_enabled === 'false')) {
      return res.status(403).json({ error: 'الدردشة معطلة حالياً' });
    }

    await ensureMessagesColumns();

    const { receiver_id, product_id, conversation_id, content, image_url, audio_url } = req.body;
    const senderId = req.user.id;

    if (
      (!content || !String(content).trim()) &&
      (!image_url || !String(image_url).trim()) &&
      (!audio_url || !String(audio_url).trim())
    ) {
      return res.status(400).json({ error: 'Message content, image_url, or audio_url is required' });
    }

    const messageContent = (content || '').trim();
    const hasImage = !!(image_url && String(image_url).trim());
    const hasAudio = !!(audio_url && String(audio_url).trim());
    const lastMessagePreview = messageContent || (hasAudio ? '🎙 رسالة صوتية' : (hasImage ? '📷 صورة' : 'رسالة'));

    // Find or create conversation
    let conv;
    let resolvedReceiverId = receiver_id;

    if (conversation_id) {
      conv = await db.query(
        'SELECT * FROM conversations WHERE id = $1 AND (buyer_id = $2 OR seller_id = $2)',
        [conversation_id, senderId]
      );

      if (conv.rows.length === 0) {
        return res.status(404).json({ error: 'Conversation not found' });
      }

      const row = conv.rows[0];
      resolvedReceiverId = row.buyer_id === senderId ? row.seller_id : row.buyer_id;
    } else {
      if (!resolvedReceiverId) {
        return res.status(400).json({ error: 'receiver_id is required' });
      }

      if (product_id) {
        conv = await db.query(
          `SELECT * FROM conversations WHERE
           ((buyer_id = $1 AND seller_id = $2) OR (buyer_id = $2 AND seller_id = $1))
           AND product_id = $3`,
          [senderId, resolvedReceiverId, product_id]
        );
      } else {
        conv = await db.query(
          `SELECT * FROM conversations WHERE
           ((buyer_id = $1 AND seller_id = $2) OR (buyer_id = $2 AND seller_id = $1))
           AND product_id IS NULL`,
          [senderId, resolvedReceiverId]
        );
      }
    }

    let conversationId;
    if (conv.rows.length === 0) {
      // Determine buyer/seller
      const senderRole = req.user.role;
      const buyerId = senderRole === 'buyer' ? senderId : resolvedReceiverId;
      const sellerId = senderRole === 'buyer' ? resolvedReceiverId : senderId;

      const newConv = await db.query(
        `INSERT INTO conversations (buyer_id, seller_id, product_id, last_message, last_message_at)
         VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
         RETURNING *`,
        [buyerId, sellerId, product_id, lastMessagePreview]
      );
      conversationId = newConv.rows[0].id;
    } else {
      conversationId = conv.rows[0].id;
    }

    // Insert message
    const msgResult = await db.query(
      `INSERT INTO messages (conversation_id, sender_id, content, image_url, audio_url)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [conversationId, senderId, messageContent, image_url || null, audio_url || null]
    );

    // Update conversation
    const conversationRow = conv.rows[0] || {};
    const isBuyer = senderId === (conversationRow.buyer_id || senderId);
    await db.query(
      `UPDATE conversations SET last_message = $1, last_message_at = CURRENT_TIMESTAMP,
       ${isBuyer ? 'seller_unread = seller_unread + 1' : 'buyer_unread = buyer_unread + 1'},
       updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [lastMessagePreview, conversationId]
    );

    res.status(201).json({ message: msgResult.rows[0], conversation_id: conversationId });
  } catch (err) {
    next(err);
  }
};

const startConversation = async (req, res, next) => {
  try {
    const { seller_id, product_id, message } = req.body;
    const buyerId = req.user.id;

    // Check if conversation exists
    let conv = await db.query(
      `SELECT * FROM conversations WHERE buyer_id = $1 AND seller_id = $2 AND product_id = $3`,
      [buyerId, seller_id, product_id || null]
    );

    if (conv.rows.length > 0) {
      // Send message to existing conversation
      req.body = { receiver_id: seller_id, product_id, content: message };
      return sendMessage(req, res, next);
    }

    const newConv = await db.query(
      `INSERT INTO conversations (buyer_id, seller_id, product_id, last_message, last_message_at, seller_unread)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, 1)
       RETURNING *`,
      [buyerId, seller_id, product_id, message]
    );

    await db.query(
      `INSERT INTO messages (conversation_id, sender_id, content)
       VALUES ($1, $2, $3)`,
      [newConv.rows[0].id, buyerId, message]
    );

    res.status(201).json({ conversation: newConv.rows[0] });
  } catch (err) {
    next(err);
  }
};

const uploadChatImage = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Image file is required' });
    }

    const imageUrl = `/uploads/${req.file.filename}`;
    res.status(201).json({ image_url: imageUrl });
  } catch (err) {
    next(err);
  }
};

const uploadChatMedia = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Media file is required' });
    }

    const mediaUrl = `/uploads/${req.file.filename}`;
    const mime = (req.file.mimetype || '').toLowerCase();
    const ext = path.extname(req.file.originalname || '').toLowerCase();
    const audioExtensions = ['.m4a', '.mp3', '.aac', '.wav', '.ogg', '.webm', '.amr', '.3gp'];
    const isAudio = mime.startsWith('audio/') || audioExtensions.includes(ext);

    if (isAudio) {
      return res.status(201).json({ audio_url: mediaUrl });
    }

    return res.status(201).json({ image_url: mediaUrl });
  } catch (err) {
    next(err);
  }
};

module.exports = { getConversations, getMessages, sendMessage, startConversation, uploadChatImage, uploadChatMedia };
