const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);

// Настраиваем Socket.IO с поддержкой CORS (чтобы работало и с GitHub Pages)
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Раздаем index.html при заходе на сервер через браузер
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname)));

const lobbies = new Map();
const KILL_LIMIT = 20;

// Генератор 5-значного кода лобби (без похожих символов 0/O, 1/I)
function makeCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  do {
    code = '';
    for (let i = 0; i < 5; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }
  } while (lobbies.has(code));
  return code;
}

// Формат состояния лобби, который ждёт клиент в событии 'lobby' и 'game:start'
function getLobbyPayload(lobby) {
  return {
    code: lobby.code,
    host: lobby.host,
    limit: lobby.limit,
    players: Array.from(lobby.players.values()).map(p => ({
      id: p.id,
      n: p.n,
      k: p.k,
      d: p.d
    }))
  };
}

// Таблица счёта для событий 'p:k' и 'game:end'
function getBoard(lobby) {
  return Array.from(lobby.players.values()).map(p => ({
    id: p.id,
    k: p.k,
    d: p.d
  }));
}

io.on('connection', (socket) => {
  let currentCode = null;

  function leaveCurrentLobby() {
    if (!currentCode) return;
    const code = currentCode;
    const lobby = lobbies.get(code);
    currentCode = null;
    socket.leave(code);

    if (!lobby) return;
    lobby.players.delete(socket.id);

    // Уведомляем остальных, что игрок вышел
    socket.to(code).emit('p:left', socket.id);

    if (lobby.players.size === 0) {
      lobbies.delete(code);
    } else {
      // Если вышел хост — передаём корону следующему игроку
      if (lobby.host === socket.id) {
        lobby.host = lobby.players.keys().next().value;
      }
      io.to(code).emit('lobby', getLobbyPayload(lobby));
    }
  }

  // 1. Создание лобби
  socket.on('lobby:create', (data, cb) => {
    leaveCurrentLobby();
    const code = makeCode();
    const name = String(data?.name || 'Игрок').trim().slice(0, 14) || 'Игрок';

    const lobby = {
      code,
      host: socket.id,
      limit: KILL_LIMIT,
      started: false,
      players: new Map([
        [socket.id, { id: socket.id, n: name, k: 0, d: 0, hp: 100, dead: false }]
      ])
    };

    lobbies.set(code, lobby);
    currentCode = code;
    socket.join(code);

    if (typeof cb === 'function') cb({ ok: true, code });
    io.to(code).emit('lobby', getLobbyPayload(lobby));
  });

  // 2. Вход в лобби по 5-значному коду
  socket.on('lobby:join', (data, cb) => {
    const code = String(data?.code || '').trim().toUpperCase();
    const lobby = lobbies.get(code);

    if (!lobby) {
      if (typeof cb === 'function') cb({ ok: false, err: 'Лобби не найдено' });
      return;
    }
    if (lobby.players.size >= 5) {
      if (typeof cb === 'function') cb({ ok: false, err: 'Лобби переполнено (макс. 5)' });
      return;
    }

    leaveCurrentLobby();
    const name = String(data?.name || 'Игрок').trim().slice(0, 14) || 'Игрок';
    lobby.players.set(socket.id, {
      id: socket.id,
      n: name,
      k: 0,
      d: 0,
      hp: 100,
      dead: false
    });

    currentCode = code;
    socket.join(code);

    if (typeof cb === 'function') cb({ ok: true, code });
    io.to(code).emit('lobby', getLobbyPayload(lobby));

    // Если бой уже идёт, сразу запускаем матч для вошедшего
    if (lobby.started) {
      socket.emit('game:start', getLobbyPayload(lobby));
    }
  });

  // 3. Выход из лобби
  socket.on('lobby:leave', () => {
    leaveCurrentLobby();
  });

  // 4. Запуск игры хостом
  socket.on('lobby:start', () => {
    if (!currentCode) return;
    const lobby = lobbies.get(currentCode);
    if (!lobby || lobby.host !== socket.id) return;

    lobby.started = true;
    lobby.players.forEach(p => {
      p.k = 0;
      p.d = 0;
      p.hp = 100;
      p.dead = false;
    });

    io.to(currentCode).emit('game:start', getLobbyPayload(lobby));
  });

  // 5. Координаты и поворот игрока: [x, y, z, yaw, weaponName]
  socket.on('p:s', (arr) => {
    if (!currentCode || !Array.isArray(arr)) return;
    socket.volatile.to(currentCode).emit('p:s', socket.id, arr);
  });

  // 6. Респавн игрока: [x, y, z]
  socket.on('p:r', (pos) => {
    if (!currentCode || !Array.isArray(pos)) return;
    const lobby = lobbies.get(currentCode);
    if (!lobby) return;
    const player = lobby.players.get(socket.id);
    if (player) {
      player.hp = 100;
      player.dead = false;
    }
    socket.to(currentCode).emit('p:r', socket.id, pos);
  });

  // 7. Звук выстрела для окружающих
  socket.on('p:f', (weaponName) => {
    if (!currentCode) return;
    socket.to(currentCode).emit('p:f', socket.id, String(weaponName || ''));
  });

  // 8. Попадание по игроку: { to, d, hs, w }
  socket.on('p:h', (hit) => {
    if (!currentCode || !hit) return;
    const lobby = lobbies.get(currentCode);
    if (!lobby || !lobby.started) return;

    const killer = lobby.players.get(socket.id);
    const victim = lobby.players.get(hit.to);
    if (!killer || !victim || killer.dead || victim.dead) return;

    const dmg = Math.max(1, Math.min(500, Number(hit.d) || 0));
    victim.hp = Math.max(0, victim.hp - dmg);

    if (victim.hp > 0) {
      io.to(currentCode).emit('p:hp', victim.id, victim.hp);
    } else {
      victim.dead = true;
      victim.d += 1;
      killer.k += 1;

      const board = getBoard(lobby);
      io.to(currentCode).emit('p:k', {
        k: killer.id,
        v: victim.id,
        w: String(hit.w || 'AK-47'),
        hs: Boolean(hit.hs),
        board
      });

      // Если кто-то набрал 20 фрагов — конец матча
      if (killer.k >= lobby.limit) {
        lobby.started = false;
        io.to(currentCode).emit('game:end', {
          win: killer.id,
          board
        });
      }
    }
  });

  socket.on('disconnect', () => {
    leaveCurrentLobby();
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Сервер запущен на http://localhost:${PORT}`);
});
