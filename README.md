# Tri-Game-Odyssey

Tri-Game-Odyssey is a multiplayer game platform built with Django and WebSockets. It currently supports live Tic-Tac-Toe matches and is designed to expand into tournament-style play with multiple mini-games and private friend rooms.

## Project Introduction

This project is an early-stage real-time gaming website. Players connect through a browser and play live matches using WebSocket-based communication. The current prototype features a polished Tic-Tac-Toe game with modern UI, real-time gameplay, and tournament-ready architecture.

**Current Features:**
- Real-time Tic-Tac-Toe with WebSocket communication
- Modern, responsive UI with animations
- Automatic player assignment (X/O)
- Win detection and highlighting
- Game reset functionality
- Connection status indicators
- Turn-based gameplay

## Architecture and Tech Stack

The system is built on Django with asynchronous WebSocket support.

- Backend: Django with Channels
- ASGI server: Daphne
- Real-time messaging: Redis channel layer
- Frontend: HTML, CSS, JavaScript
- Database: SQLite for development

This architecture supports live gameplay, room-based sessions, and scalable expansion to additional games.

## Installation and Run

### Windows
```powershell
git clone <repository-url>
cd Tri-Game-Odyssey
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
winget install Redis.Redis
python -m daphne firstProject.asgi:application --port 8000
```

### macOS
```bash
git clone <repository-url>
cd Tri-Game-Odyssey
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
brew install redis
brew services start redis
python -m daphne firstProject.asgi:application --port 8000
```

### Ubuntu / WSL
```bash
git clone <repository-url>
cd Tri-Game-Odyssey
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
sudo apt install redis-server
sudo service redis-server start
python -m daphne firstProject.asgi:application --port 8000
```

After running the server, open:

```
http://localhost:8000/
```

## Notes

- The project is currently in early development.
- Additional games and tournament features are planned.
- For deeper implementation details, refer to ARCHITECTURE.md and DEVELOPMENT_GUIDE.md.


### WebSocket Connection Fails

1. Ensure Redis is running: `redis-cli ping`
2. Run the ASGI server with Daphne instead of the default Django WSGI server
3. Verify `ASGI_APPLICATION` is set in `settings.py`
4. Check browser console for detailed error messages

### "Redis connection refused"

- Ensure Redis server is started
- Verify Redis is running on localhost:6379
- Check CHANNEL_LAYERS configuration in settings.py

### "ModuleNotFoundError: No module named 'channels'"

- Activate your virtual environment
- Run: `pip install -r requirements.txt`

## Dependencies

All dependencies are listed in `requirements.txt`:

```
Django==4.2.6
sqlparse==0.4.4
tzdata==2023.3
channels==4.3.2
channels-redis==4.3.0
redis==7.4.0
daphne==4.2.1
```

## License

MIT License - feel free to use this project for learning and development.

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## Support

For questions or issues:
1. Check the `learn.md` file for concepts explanation
2. Review the Django Channels documentation: https://channels.readthedocs.io/
3. Check Django documentation: https://docs.djangoproject.com/

## Authors

Created as a learning project for understanding real-time communication with WebSockets and Django Channels.