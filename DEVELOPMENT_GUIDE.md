# Quick Start: Multi-Game Tournament Platform Development

## Overview

You're transforming Tri-Game-Odyssey from a simple Tic-Tac-Toe game into a tournament platform where:
- Players compete in 3 different mini-games
- Tournament format: Best-of-3 (first to win 2 games wins)
- Public matchmaking and friend rooms
- Live scoring and leaderboards

## Before You Start

Read these files in order:
1. ARCHITECTURE.md - Complete system design
2. This file - Quick development guide
3. learn.md - WebSocket/Channels concepts

## Current State

You have:
- Basic Tic-Tac-Toe game with WebSockets
- Django + Channels + Redis setup
- ASGI server configured

You need to add:
- User authentication
- Database models for tournaments
- Multiple games
- Tournament logic

## Development Strategy

### Step 1: Switch to PostgreSQL (Optional but Recommended)

SQLite is fine for development, but PostgreSQL is better for production and multi-user systems.

```bash
# Windows
pip install psycopg2-binary

# macOS/Linux
pip install psycopg2

# Then update settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'trig_odyssey',
        'USER': 'postgres',
        'PASSWORD': 'your_password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

### Step 2: Start with User Authentication

This is the foundation for everything else.

```bash
# Install Django authentication packages
pip install djangorestframework djangorestframework-simplejwt django-cors-headers
```

Create core app:
```bash
python manage.py startapp core
```

Add to settings.py:
```python
INSTALLED_APPS = [
    ...
    'rest_framework',
    'corsheaders',
    'core',
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
}
```

### Step 3: Create User Model

In core/models.py:
```python
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    avatar = models.ImageField(upload_to='avatars/', null=True)
    bio = models.TextField(blank=True)
    elo_rating = models.IntegerField(default=1600)
    total_wins = models.IntegerField(default=0)
    total_losses = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return self.username
```

Update settings.py:
```python
AUTH_USER_MODEL = 'core.User'
```

### Step 4: Create Models for Tournaments

In core/models.py, add:
```python
class Friendship(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('blocked', 'Blocked'),
    ]
    
    user1 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='friends_sent')
    user2 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='friends_received')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

class Tournament(models.Model):
    TYPES = [
        ('public', 'Public'),
        ('friend', 'Friend Room'),
    ]
    
    player1 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tournaments_p1')
    player2 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tournaments_p2', null=True)
    tournament_type = models.CharField(max_length=20, choices=TYPES)
    room_code = models.CharField(max_length=10, unique=True)
    
    player1_score = models.IntegerField(default=0)
    player2_score = models.IntegerField(default=0)
    winner = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='won_tournaments')
    
    status = models.CharField(max_length=20, default='waiting')
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
```

### Step 5: Create Base Game Consumer

Create games/base.py:
```python
from channels.generic.websocket import AsyncWebsocketConsumer
import json

class AbstractGameConsumer(AsyncWebsocketConsumer):
    """Base class for all game types"""
    
    game_type = None  # Override in subclass
    
    async def connect(self):
        self.room_name = self.scope['url_route']['kwargs']['room_name']
        self.room_group_name = f"{self.game_type}_{self.room_name}"
        
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        
        await self.initialize_game()
        await self.accept()
    
    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
    
    async def receive(self, text_data):
        data = json.loads(text_data)
        action = data.get('action')
        
        if action == 'move':
            await self.handle_move(data)
        elif action == 'forfeit':
            await self.handle_forfeit(data)
    
    async def initialize_game(self):
        """Override in subclass"""
        raise NotImplementedError
    
    async def handle_move(self, data):
        """Override in subclass"""
        raise NotImplementedError
    
    async def handle_forfeit(self, data):
        """Handle player forfeiting"""
        await self.end_game('player2')
    
    async def end_game(self, winner):
        """Send game end event"""
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'game_end',
                'winner': winner,
            }
        )
    
    async def game_end(self, event):
        """Called when game ends"""
        await self.send(text_data=json.dumps({
            'action': 'game_end',
            'winner': event['winner'],
        }))
```

### Step 6: Refactor TicTacToe to Use Base

Update tiktactoe/consumers.py:
```python
from games.base import AbstractGameConsumer

class TicTacToeGameConsumer(AbstractGameConsumer):
    game_type = 'tictactoe'
    
    async def initialize_game(self):
        self.board = [None] * 9
        self.current_player = 'X'
    
    async def handle_move(self, data):
        move = data.get('move')
        
        # Validate move
        if not self.is_valid_move(move):
            await self.send(text_data=json.dumps({
                'action': 'error',
                'message': 'Invalid move'
            }))
            return
        
        # Update board
        self.board[move] = self.current_player
        
        # Check winner
        winner = self.check_winner()
        if winner:
            await self.end_game(winner)
            return
        
        # Check draw
        if self.is_draw():
            await self.end_game('draw')
            return
        
        # Toggle player
        self.current_player = 'O' if self.current_player == 'X' else 'X'
        
        # Broadcast move
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'move_made',
                'move': move,
                'player': self.current_player,
                'board': self.board,
            }
        )
    
    def is_valid_move(self, move):
        return 0 <= move <= 8 and self.board[move] is None
    
    def check_winner(self):
        # Win conditions
        win_patterns = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],  # rows
            [0, 3, 6], [1, 4, 7], [2, 5, 8],  # cols
            [0, 4, 8], [2, 4, 6]               # diagonals
        ]
        
        for pattern in win_patterns:
            if all(self.board[i] == self.current_player for i in pattern):
                return self.current_player
        return None
    
    def is_draw(self):
        return all(cell is not None for cell in self.board)
    
    async def move_made(self, event):
        await self.send(text_data=json.dumps({
            'action': 'move_made',
            'move': event['move'],
            'player': event['player'],
            'board': event['board'],
        }))
```

## Recommended Implementation Order

1. **Core Users** (Days 1-3)
   - [ ] Create User model
   - [ ] Create authentication endpoints
   - [ ] Create login/register pages

2. **Lobby System** (Days 4-5)
   - [ ] Create Lobby page
   - [ ] Implement matchmaking queue
   - [ ] Create LobbyConsumer

3. **Refactor Base** (Days 6-7)
   - [ ] Create AbstractGameConsumer
   - [ ] Refactor TicTacToe
   - [ ] Test the refactored game

4. **New Games** (Days 8-10)
   - [ ] Rock-Paper-Scissors
   - [ ] Connect Four
   - [ ] Game selection logic

5. **Tournament System** (Days 11-14)
   - [ ] Tournament model
   - [ ] TournamentConsumer
   - [ ] Score tracking
   - [ ] Best-of-3 logic

## File Structure to Create

```
core/
├── __init__.py
├── admin.py
├── apps.py
├── models.py              # User, Friendship, Tournament
├── views.py               # Auth views
├── serializers.py         # DRF serializers
├── consumers.py           # LobbyConsumer
├── routing.py
├── urls.py
├── migrations/
└── templates/

games/
├── __init__.py
├── base.py               # AbstractGameConsumer
├── validators.py
└── utils.py

tournament/
├── __init__.py
├── models.py
├── consumers.py          # TournamentConsumer
├── services.py
├── routing.py
└── utils.py
```

## Database Setup

```bash
# Create migrations
python manage.py makemigrations core

# Apply migrations
python manage.py migrate

# Create superuser for admin
python manage.py createsuperuser
```

## Common Commands

```bash
# Start development server
python manage.py runserver

# Make migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Access admin
# Navigate to http://localhost:8000/admin

# Run tests
python manage.py test

# Create shell for testing
python manage.py shell
```

## Testing Your Progress

### Test 1: User Authentication
```python
# In Django shell
from core.models import User

# Create user
user = User.objects.create_user('testuser', 'test@example.com', 'password123')

# Verify
print(user.username)
print(user.elo_rating)  # Should be 1600
```

### Test 2: Lobby Connection
```javascript
// In browser console
const socket = new WebSocket('ws://localhost:8000/ws/lobby/');
socket.onmessage = (e) => console.log('Message:', e.data);
socket.send(JSON.stringify({action: 'find_match'}));
```

### Test 3: Game Flow
```python
# Test TicTacToe with new consumer
from tiktactoe.consumers import TicTacToeGameConsumer

# Create consumer instance and test
consumer = TicTacToeGameConsumer()
# ... test various moves
```

## Key Concepts to Remember

1. **WebSocket Consumers** - Handle real-time connections
2. **Channel Groups** - Broadcast to multiple connections
3. **Models** - Store persistent data
4. **Serializers** - Convert models to JSON
5. **Authentication** - Verify user identity
6. **Tournament Logic** - Best-of-3, score tracking

## Next Actions

1. Read ARCHITECTURE.md completely
2. Create User model and migrations
3. Build authentication system
4. Test user registration/login
5. Create Lobby page
6. Implement matchmaking

## Questions to Ask Yourself

- Do I understand the database schema?
- Can I explain the tournament flow?
- Do I know what each WebSocket message does?
- Can I create a new game type?

## Resources

- Django Docs: https://docs.djangoproject.com/
- Django Channels: https://channels.readthedocs.io/
- DRF: https://www.django-rest-framework.org/
- PostgreSQL: https://www.postgresql.org/docs/

Good luck! Feel free to start with any component. The foundation is already solid! 🚀
