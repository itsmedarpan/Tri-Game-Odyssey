# Multi-Game Tournament Platform - Architecture & Implementation Plan

## Project Vision

Transform Tri-Game-Odyssey into a real-time multiplayer gaming platform where:
- Players can compete in multiple mini-games
- Tournament format: Best-of-3 (first to win 2 games)
- Lobby system for matchmaking
- Friend rooms for private play
- Live spectating
- Player statistics and leaderboards

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│             FRONTEND (SPA - Vue/React)              │
│ ┌───────────────────────────────────────────────┐  │
│ │ Lobby Page                                    │  │
│ │ ├─ Quick Play                                 │  │
│ │ ├─ Create Friend Room                         │  │
│ │ └─ View Friends/Leaderboard                   │  │
│ │                                               │  │
│ │ Game Selection Screen                         │  │
│ │ ├─ Tic-Tac-Toe                                │  │
│ │ ├─ Rock-Paper-Scissors                        │  │
│ │ └─ Connect Four (etc.)                        │  │
│ │                                               │  │
│ │ Tournament Room                               │  │
│ │ ├─ Game 1/2/3 Display                         │  │
│ │ ├─ Scores (0-0, 1-0, etc.)                    │  │
│ │ └─ Winner Announcement                        │  │
│ └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
           ↕ WebSocket
┌─────────────────────────────────────────────────────┐
│              BACKEND (Django + Channels)            │
│ ┌───────────────────────────────────────────────┐  │
│ │ Game Routing                                  │  │
│ │ ├─ TicTacToeConsumer                          │  │
│ │ ├─ RockPaperScissorsConsumer                  │  │
│ │ ├─ ConnectFourConsumer                        │  │
│ │ └─ TournamentConsumer                         │  │
│ │                                               │  │
│ │ Tournament Management                         │  │
│ │ ├─ Room Creation                              │  │
│ │ ├─ Player Matching                            │  │
│ │ ├─ Score Tracking                             │  │
│ │ └─ Results Persistence                        │  │
│ │                                               │  │
│ │ User Management                               │  │
│ │ ├─ Authentication                             │  │
│ │ ├─ Friends List                               │  │
│ │ └─ Statistics/ELO                             │  │
│ └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
           ↕ Redis Layer
┌─────────────────────────────────────────────────────┐
│                   REDIS                             │
│ ├─ Channel Groups (tournament rooms)                │
│ ├─ Session Data                                     │
│ ├─ Game State Cache                                 │
│ └─ Pub/Sub for Cross-Server Communication          │
└─────────────────────────────────────────────────────┘
           ↕ Database Query
┌─────────────────────────────────────────────────────┐
│              DATABASE (PostgreSQL)                  │
│ ├─ Users                                            │
│ ├─ Tournaments/Matches                              │
│ ├─ Game Results                                     │
│ ├─ Friendships                                      │
│ ├─ Player Statistics                                │
│ └─ Leaderboard Data                                 │
└─────────────────────────────────────────────────────┘
```

## Database Schema

### Core Models

```python
# User & Authentication
class User(models.Model):
    username = CharField(max_length=50, unique=True)
    email = EmailField(unique=True)
    avatar = ImageField(optional=True)
    elo_rating = IntegerField(default=1600)
    total_wins = IntegerField(default=0)
    total_losses = IntegerField(default=0)
    created_at = DateTimeField(auto_now_add=True)
    updated_at = DateTimeField(auto_now=True)

# Friend System
class Friendship(models.Model):
    user1 = ForeignKey(User, on_delete=CASCADE, related_name='friend_requests_sent')
    user2 = ForeignKey(User, on_delete=CASCADE, related_name='friend_requests_received')
    status = CharField(max_length=20, choices=[('pending', 'Pending'), ('accepted', 'Accepted')])
    created_at = DateTimeField(auto_now_add=True)

# Tournament/Match
class Tournament(models.Model):
    TYPES = [
        ('public', 'Public Matchmaking'),
        ('friend', 'Friend Room'),
        ('ranked', 'Ranked'),
    ]
    
    player1 = ForeignKey(User, on_delete=CASCADE, related_name='tournaments_as_p1')
    player2 = ForeignKey(User, on_delete=CASCADE, related_name='tournaments_as_p2', null=True)
    tournament_type = CharField(max_length=20, choices=TYPES)
    room_code = CharField(max_length=10, unique=True)  # Friends can join via code
    status = CharField(max_length=20, choices=[('waiting', 'Waiting'), ('active', 'Active'), ('finished', 'Finished')])
    
    player1_score = IntegerField(default=0)  # Number of games won
    player2_score = IntegerField(default=0)
    winner = ForeignKey(User, on_delete=SET_NULL, null=True, related_name='won_tournaments')
    
    created_at = DateTimeField(auto_now_add=True)
    finished_at = DateTimeField(null=True)

# Individual Game Result
class GameResult(models.Model):
    GAME_TYPES = [
        ('tictactoe', 'Tic-Tac-Toe'),
        ('rps', 'Rock-Paper-Scissors'),
        ('connectfour', 'Connect Four'),
    ]
    
    tournament = ForeignKey(Tournament, on_delete=CASCADE, related_name='games')
    game_type = CharField(max_length=20, choices=GAME_TYPES)
    game_number = IntegerField()  # 1, 2, or 3
    
    player1 = ForeignKey(User, on_delete=CASCADE, related_name='games_as_p1')
    player2 = ForeignKey(User, on_delete=CASCADE, related_name='games_as_p2')
    winner = ForeignKey(User, on_delete=CASCADE, related_name='won_games')
    
    duration = IntegerField()  # seconds
    game_data = JSONField()  # Store full game state
    
    created_at = DateTimeField(auto_now_add=True)

# Player Statistics
class PlayerStatistic(models.Model):
    user = OneToOneField(User, on_delete=CASCADE)
    
    tictactoe_wins = IntegerField(default=0)
    tictactoe_losses = IntegerField(default=0)
    
    rps_wins = IntegerField(default=0)
    rps_losses = IntegerField(default=0)
    
    connectfour_wins = IntegerField(default=0)
    connectfour_losses = IntegerField(default=0)
    
    tournament_wins = IntegerField(default=0)
    tournament_losses = IntegerField(default=0)
    
    updated_at = DateTimeField(auto_now=True)
```

## Project Structure

### New Directory Layout

```
Tri-Game-Odyssey/
├── firstProject/
│   ├── settings.py
│   ├── asgi.py
│   ├── urls.py
│   └── wsgi.py
├── core/                          # NEW: Core app (users, auth, lobby)
│   ├── models.py
│   ├── views.py
│   ├── serializers.py
│   ├── urls.py
│   └── consumers.py              # LobbyConsumer, MatchmakingConsumer
├── games/                         # NEW: Base game logic
│   ├── base.py                   # Abstract GameConsumer class
│   ├── validators.py
│   └── utils.py
├── tictactoe/
│   ├── consumers.py              # TicTacToeGameConsumer (extends base)
│   ├── routing.py
│   └── templates/
├── rockpaperscissors/             # NEW: Rock-Paper-Scissors game
│   ├── consumers.py
│   ├── routing.py
│   └── templates/
├── connectfour/                   # NEW: Connect Four game
│   ├── consumers.py
│   ├── routing.py
│   └── templates/
├── tournament/                    # NEW: Tournament logic
│   ├── models.py
│   ├── consumers.py              # TournamentConsumer
│   ├── routing.py
│   ├── services.py               # Game selection, score tracking
│   └── utils.py
├── static/
│   ├── css/
│   ├── js/
│   └── images/
├── templates/
│   ├── base.html
│   ├── lobby.html
│   ├── room.html
│   └── tournament.html
├── requirements.txt
├── manage.py
└── README.md
```

## Implementation Phases

### Phase 1: User System & Lobby (Weeks 1-2)

**Tasks:**
1. Create User model with authentication
2. Build login/registration pages
3. Create lobby page UI
4. Build LobbyConsumer for WebSocket communication
5. Implement matchmaking queue
6. Add friend system

**Key Files to Create:**
```
core/models.py - User, Friendship
core/consumers.py - LobbyConsumer, MatchmakingConsumer
core/views.py - Auth views
core/urls.py
templates/lobby.html
static/js/lobby.js
```

**Database Migrations:**
```bash
python manage.py makemigrations
python manage.py migrate
```

### Phase 2: Refactor Tic-Tac-Toe & Create Base Game (Weeks 2-3)

**Tasks:**
1. Create AbstractGameConsumer base class
2. Refactor existing TicTacToe to use base
3. Implement Rock-Paper-Scissors
4. Implement Connect Four
5. Create game selection logic

**Key Files:**
```
games/base.py - AbstractGameConsumer
games/validators.py
games/utils.py
tictactoe/consumers.py - Refactored
rockpaperscissors/consumers.py - NEW
connectfour/consumers.py - NEW
```

**Base Class Structure:**
```python
class AbstractGameConsumer(AsyncWebsocketConsumer):
    """Base class for all game consumers"""
    
    async def connect(self):
        # Join room, setup game state
        pass
    
    async def disconnect(self, close_code):
        # Clean up, store results
        pass
    
    async def receive(self, text_data):
        # Route moves to specific handler
        pass
    
    async def validate_move(self, move):
        # Override in subclasses
        pass
    
    async def process_move(self, move):
        # Override in subclasses
        pass
    
    async def check_winner(self):
        # Override in subclasses
        pass
    
    async def end_game(self, winner):
        # Store result, notify tournament
        pass
```

### Phase 3: Tournament Management (Weeks 3-4)

**Tasks:**
1. Create Tournament model
2. Build TournamentConsumer
3. Implement best-of-3 logic
4. Create score tracking
5. Implement winner announcement
6. Store game results

**Key Files:**
```
tournament/models.py
tournament/consumers.py
tournament/services.py
tournament/utils.py
templates/tournament.html
static/js/tournament.js
```

**Tournament Flow:**
```python
async def start_tournament(self):
    # Select first game randomly
    game = random.choice(['tictactoe', 'rps', 'connectfour'])
    self.current_game = game
    self.game_number = 1

async def on_game_end(self, winner, game_type):
    # Update scores
    if winner == self.player1:
        self.player1_score += 1
    else:
        self.player2_score += 1
    
    # Check if tournament finished
    if self.player1_score == 2:
        await self.end_tournament(self.player1)
    elif self.player2_score == 2:
        await self.end_tournament(self.player2)
    else:
        # Start next game
        await self.next_game()
```

### Phase 4: UI & Polish (Weeks 4-5)

**Tasks:**
1. Build responsive lobby UI
2. Create game selection interface
3. Build tournament room with score display
4. Implement leaderboards
5. Add player profiles
6. Create matchmaking animations

### Phase 5: Features & Deployment (Week 6+)

**Tasks:**
1. Add spectator mode
2. Implement chat system
3. Add game replays
4. Create statistics dashboard
5. Deploy to production
6. Setup SSL/TLS
7. Configure Redis clustering

## Technology Choices

### Frontend

Option 1: Plain HTML/CSS/JavaScript (Simple, Current approach)
Option 2: Vue.js (Recommended, better for complex UI)
Option 3: React (Most popular, steeper learning curve)

**Recommendation:** Start with Vue.js for moderate complexity

```bash
npm install vue@3
```

### Backend Enhancements

```python
# settings.py additions
INSTALLED_APPS = [
    'rest_framework',           # For API endpoints
    'rest_framework_jwt',       # JWT authentication
    'corsheaders',              # CORS support
    'channels',
    'core',
    'games',
    'tictactoe',
    'rockpaperscissors',
    'connectfour',
    'tournament',
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'trig_game_odyssey',
        'USER': 'postgres',
        'PASSWORD': 'password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

## WebSocket Message Protocol

### Lobby Messages

```json
// Client: Search for match
{"action": "find_match", "skill_level": "beginner"}

// Server: Match found
{"action": "match_found", "opponent": "PlayerName", "tournament_id": "12345"}

// Client: Accept match
{"action": "accept_match", "tournament_id": "12345"}

// Server: Redirecting to tournament room
{"action": "redirect", "url": "/tournament/12345/"}
```

### Tournament Messages

```json
// Server: Tournament started
{"action": "tournament_start", "games": ["tictactoe", "rps", "connectfour"], "current_game": "tictactoe"}

// Server: Game started
{"action": "game_start", "game_type": "tictactoe"}

// Game-specific moves (passed to game consumer)
{"action": "move", "game_type": "tictactoe", "move": 5}

// Server: Game ended
{"action": "game_end", "winner": "player1", "current_score": {"player1": 1, "player2": 0}}

// Server: Tournament ended
{"action": "tournament_end", "winner": "PlayerName", "stats": {...}}
```

### Friend Room Messages

```json
// Client: Create friend room
{"action": "create_room", "friend_username": "Player2"}

// Server: Room created
{"action": "room_created", "room_code": "ABC123", "invite_link": "/invite/ABC123"}

// Client: Join friend room
{"action": "join_room", "room_code": "ABC123"}

// Server: Friend joined
{"action": "friend_joined", "friend_name": "Player2"}
```

## API Endpoints

### Authentication
```
POST   /api/auth/register/
POST   /api/auth/login/
POST   /api/auth/logout/
GET    /api/auth/me/
```

### Users & Friends
```
GET    /api/users/<username>/
GET    /api/users/<username>/stats/
GET    /api/users/leaderboard/
GET    /api/friends/
POST   /api/friends/<user_id>/request/
POST   /api/friends/<user_id>/accept/
DELETE /api/friends/<user_id>/remove/
```

### Tournaments
```
POST   /api/tournaments/quick-play/
POST   /api/tournaments/friend-room/
GET    /api/tournaments/<id>/
GET    /api/tournaments/<id>/results/
GET    /api/tournaments/history/
```

## Implementation Roadmap

### Week 1: Foundation
- Day 1-2: User model, authentication
- Day 3-4: Core models (Friendship, Tournament, GameResult)
- Day 5: Lobby page and basic matching logic

### Week 2: First Game Refactor
- Day 1-2: Abstract game consumer
- Day 3-4: Refactor TicTacToe
- Day 5: Test and debug

### Week 3: New Games
- Day 1-2: Rock-Paper-Scissors
- Day 3-4: Connect Four
- Day 5: Game selection logic

### Week 4: Tournament System
- Day 1-2: Tournament consumer
- Day 3-4: Best-of-3 logic
- Day 5: Score tracking and results

### Week 5: UI & Frontend
- Day 1-2: Lobby UI
- Day 3-4: Tournament room UI
- Day 5: Game selection interface

### Week 6: Polish & Extras
- Day 1-2: Leaderboards, stats
- Day 3-4: Friend rooms
- Day 5: Testing and optimization

## Common Patterns

### Game Consumer Pattern

```python
from games.base import AbstractGameConsumer

class MyGameConsumer(AbstractGameConsumer):
    game_type = 'mygame'
    
    async def initialize_game(self):
        self.game_state = {
            'board': [],
            'turn': 'player1',
            'moves': []
        }
    
    async def validate_move(self, move):
        # Validate move for this game
        if move not in range(valid_range):
            return False, "Invalid move"
        return True, ""
    
    async def process_move(self, move):
        # Update game state
        self.game_state['moves'].append(move)
        self.game_state['turn'] = 'player2'  # Toggle turn
    
    async def check_winner(self):
        # Check if someone won
        if len(self.game_state['moves']) >= min_moves:
            if self._is_winning_position():
                return self.current_player
        return None
    
    def _is_winning_position(self):
        # Game-specific win condition
        pass
```

### Tournament Score Tracking

```python
class TournamentConsumer(AsyncWebsocketConsumer):
    async def on_game_result(self, winner):
        if winner == self.player1_channel_name:
            self.scores['player1'] += 1
        else:
            self.scores['player2'] += 1
        
        await self.send_score_update()
        
        if self.scores['player1'] == 2:
            await self.end_tournament(self.player1_id)
        elif self.scores['player2'] == 2:
            await self.end_tournament(self.player2_id)
        else:
            await self.start_next_game()
```

## Testing Strategy

### Unit Tests

```python
# tests/test_games.py
class TicTacToeGameTest(TestCase):
    def test_valid_move(self):
        # Test valid moves
        pass
    
    def test_invalid_move(self):
        # Test invalid moves
        pass
    
    def test_win_detection(self):
        # Test win conditions
        pass

# tests/test_tournament.py
class TournamentLogicTest(TestCase):
    def test_best_of_three_logic(self):
        # Test tournament scoring
        pass
```

### WebSocket Tests

```python
# tests/test_consumers.py
class TournamentConsumerTest(TestCase):
    async def test_tournament_flow(self):
        # Test complete tournament flow
        pass
```

## Performance Considerations

1. **Database Optimization:**
   - Add database indexes on frequently queried fields
   - Use select_related() and prefetch_related()
   - Cache leaderboard data in Redis

2. **WebSocket Performance:**
   - Use Redis channels for efficient group messaging
   - Implement message compression
   - Rate limit moves (prevent spam)

3. **Scalability:**
   - Deploy multiple Daphne instances
   - Use Redis cluster for channel layers
   - Implement load balancing

## Security Considerations

1. **Authentication:**
   - Use JWT tokens
   - Implement CSRF protection
   - Validate all user inputs

2. **WebSocket Security:**
   - Validate moves server-side (never trust client)
   - Use secure WebSocket (WSS)
   - Implement rate limiting

3. **Data Protection:**
   - Hash passwords
   - Encrypt sensitive data
   - Implement SSL/TLS

## Deployment Checklist

- [ ] Database migration completed
- [ ] Environment variables configured
- [ ] Static files collected
- [ ] Media files uploaded
- [ ] Redis configured and running
- [ ] Daphne/Uvicorn configured
- [ ] SSL certificate installed
- [ ] Logging configured
- [ ] Monitoring setup
- [ ] Backup strategy implemented
- [ ] Performance tested under load

## Next Steps

1. Start with Phase 1 (User System)
2. Create migrations and test database
3. Build authentication flow
4. Create lobby interface
5. Implement basic matchmaking

Would you like me to:
1. Start building Phase 1?
2. Create the base models?
3. Set up the project structure?
4. Build specific components?
