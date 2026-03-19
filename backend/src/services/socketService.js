const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../config/database');

function setupSocket(io) {
  // Authentication middleware for Socket.io
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.query.token;
      if (!token) {
        return next(new Error('Authentication required'));
      }

      const decoded = jwt.verify(token, config.jwt.secret);
      const result = await db.query(
        'SELECT id, email, first_name, last_name, role FROM users WHERE id = $1 AND is_active = true',
        [decoded.userId]
      );

      if (result.rows.length === 0) {
        return next(new Error('User not found'));
      }

      socket.user = result.rows[0];
      next();
    } catch (err) {
      next(new Error('Invalid token'));
    }
  });

  // Track online users
  const onlineUsers = new Map();

  io.on('connection', (socket) => {
    const userId = socket.user.id;
    console.log(`🔌 User connected: ${socket.user.first_name} (${userId})`);

    // Add user to online users
    onlineUsers.set(userId, socket.id);

    // Join user's personal room
    socket.join(`user:${userId}`);

    // Notify others about online status
    socket.broadcast.emit('user:online', { userId });

    // ==================== CHAT ====================

    // Join a conversation room
    socket.on('chat:join', async (data) => {
      const { conversationId } = data;
      try {
        const conv = await db.query(
          'SELECT * FROM conversations WHERE id = $1 AND (buyer_id = $2 OR seller_id = $2)',
          [conversationId, userId]
        );
        if (conv.rows.length > 0) {
          socket.join(`conversation:${conversationId}`);
          socket.emit('chat:joined', { conversationId });
        }
      } catch (err) {
        socket.emit('error', { message: 'Failed to join conversation' });
      }
    });

    // Send a message
    socket.on('chat:message', async (data) => {
      const { conversationId, content } = data;
      try {
        // Verify user is in conversation
        const conv = await db.query(
          'SELECT * FROM conversations WHERE id = $1 AND (buyer_id = $2 OR seller_id = $2)',
          [conversationId, userId]
        );
        if (conv.rows.length === 0) return;

        // Save message
        const msgResult = await db.query(
          `INSERT INTO messages (conversation_id, sender_id, content)
           VALUES ($1, $2, $3)
           RETURNING *`,
          [conversationId, userId, content]
        );

        const message = {
          ...msgResult.rows[0],
          first_name: socket.user.first_name,
          last_name: socket.user.last_name,
        };

        // Update conversation
        const isBuyer = conv.rows[0].buyer_id === userId;
        await db.query(
          `UPDATE conversations SET last_message = $1, last_message_at = CURRENT_TIMESTAMP,
           ${isBuyer ? 'seller_unread = seller_unread + 1' : 'buyer_unread = buyer_unread + 1'},
           updated_at = CURRENT_TIMESTAMP
           WHERE id = $2`,
          [content, conversationId]
        );

        // Broadcast to conversation room
        io.to(`conversation:${conversationId}`).emit('chat:message', message);

        // Notify receiver if not in room
        const receiverId = isBuyer ? conv.rows[0].seller_id : conv.rows[0].buyer_id;
        io.to(`user:${receiverId}`).emit('chat:notification', {
          conversationId,
          message: content,
          sender: socket.user.first_name,
        });
      } catch (err) {
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // Mark messages as read
    socket.on('chat:read', async (data) => {
      const { conversationId } = data;
      try {
        const conv = await db.query(
          'SELECT * FROM conversations WHERE id = $1 AND (buyer_id = $2 OR seller_id = $2)',
          [conversationId, userId]
        );
        if (conv.rows.length === 0) return;

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

        socket.to(`conversation:${conversationId}`).emit('chat:read', { conversationId, readBy: userId });
      } catch (err) {
        socket.emit('error', { message: 'Failed to mark messages as read' });
      }
    });

    // Typing indicator
    socket.on('chat:typing', (data) => {
      const { conversationId } = data;
      socket.to(`conversation:${conversationId}`).emit('chat:typing', {
        conversationId,
        userId,
        userName: socket.user.first_name,
      });
    });

    socket.on('chat:stop-typing', (data) => {
      const { conversationId } = data;
      socket.to(`conversation:${conversationId}`).emit('chat:stop-typing', {
        conversationId,
        userId,
      });
    });

    // Leave conversation room
    socket.on('chat:leave', (data) => {
      const { conversationId } = data;
      socket.leave(`conversation:${conversationId}`);
    });

    // ==================== NOTIFICATIONS ====================

    socket.on('notification:read', async (data) => {
      // Handle notification read status
    });

    // ==================== DISCONNECT ====================

    socket.on('disconnect', () => {
      console.log(`🔌 User disconnected: ${socket.user.first_name}`);
      onlineUsers.delete(userId);
      socket.broadcast.emit('user:offline', { userId });
    });
  });

  return io;
}

module.exports = setupSocket;
