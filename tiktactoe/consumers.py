import json
from channels.generic.websocket import AsyncWebsocketConsumer

# Track connected players per room
room_players = {}

class TicTacToeConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_name = self.scope['url_route']['kwargs']['room_name']
        self.room_group_name = f'tictactoe_{self.room_name}'
        
        # Initialize room if it doesn't exist
        if self.room_name not in room_players:
            room_players[self.room_name] = {'x': None, 'o': None, 'count': 0}
        
        room_info = room_players[self.room_name]
        
        # Assign player symbol based on connection order
        if room_info['count'] == 0:
            self.player_symbol = 'X'
            room_info['x'] = self.channel_name
        elif room_info['count'] == 1:
            self.player_symbol = 'O'
            room_info['o'] = self.channel_name
        else:
            # Room is full, reject connection
            self.player_symbol = None
            await self.close()
            return
        
        room_info['count'] += 1
        self.player_color = 'blue' if self.player_symbol == 'X' else 'purple'

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

        # Notify all players about connection
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'player_connected',
                'player': self.player_symbol,
                'connected_count': room_info['count'],
            }
        )

    async def disconnect(self, close_code):
        if self.room_name in room_players:
            room_info = room_players[self.room_name]
            room_info['count'] -= 1
            
            # Clean up if room is empty
            if room_info['count'] == 0:
                del room_players[self.room_name]
            else:
                # Reset the player slot
                if self.player_symbol == 'X':
                    room_info['x'] = None
                elif self.player_symbol == 'O':
                    room_info['o'] = None
        
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        data = json.loads(text_data)

        if data.get('type') == 'move':
            move = data.get('move')
            player = data.get('player')

            if move is not None and player:
                # Broadcast move to all players in the room
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'game_move',
                        'move': move,
                        'player': player,
                    }
                )
        elif data.get('type') == 'reset':
            # Broadcast reset to all players
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'game_reset',
                }
            )

    async def player_connected(self, event):
        # Send player connection info to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'player_connected',
            'player': event['player'],
            'connected_count': event['connected_count'],
            'your_symbol': self.player_symbol,
        }))

    async def game_move(self, event):
        # Send move to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'move',
            'move': event['move'],
            'player': event['player'],
        }))

    async def game_reset(self, event):
        # Send reset signal to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'reset',
        }))

