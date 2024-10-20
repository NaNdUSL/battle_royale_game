class Client{

	Menu menu;
	Game game;
	boolean connected;
	Socket socket;
	String action;
	String username;
	String password;
	boolean send;
	boolean playing;
	boolean is_online;
	float[] vector;
	float max;
	boolean boost;
	BufferedReader in;
	PrintWriter out;
	int prevMouseX;
	int prevMouseY;

	Client(){

		this.menu = new Menu();
		this.game = new Game();
		this.connected = false;
		this.send = false;
		this.playing = false;
		this.is_online = false;
		this.boost = false;
		this.socket = new Socket();
		this.username = "";
		this.password = "";
		this.action = "";
		this.vector = new float[]{0.0f, 0.0f};
		this.max = 200.0f;
	}

	Client(String host, int port, String username, String password, String action){

		this.menu = new Menu();
		this.game = new Game();
		this.send = false;
		this.playing = false;
		this.boost = false;
		this.is_online = false;
		this.action = action;
		this.username = username;
		this.password = password;
		this.vector = new float[]{0.0f, 0.0f};
		this.max = 200.0f;
		this.prevMouseX = mouseX;
		this.prevMouseY = mouseY;

		try{

			this.socket = new Socket(host, port);
			this.set_connected(true);
			(new Sock_writer(this)).start();
			(new Sock_reader(this)).start();
			this.in = new BufferedReader(new InputStreamReader(this.socket.getInputStream()));
			this.out = new PrintWriter(this.socket.getOutputStream());
		}
		catch(Exception e){}
	}

	synchronized void set_send(boolean send){

		this.send = send;
	}

	void set_vector(float[] vector){

		this.vector = vector;
	}

	float vec_dist(float[] beg, float[] end){

		return (float)Math.sqrt((end[1] - beg[1]) * (end[1] - beg[1]) + (end[0] - beg[0]) * (end[0] - beg[0]));
	}

	synchronized void set_online(boolean is_online){

		this.is_online = is_online;
	}

	synchronized void set_playing(boolean playing){

		this.playing = playing;
	}

	synchronized void set_username(String user){

		this.username = user;
	}

	synchronized void set_password(String pass){

		this.password = pass;
	}

	synchronized void set_action(String action){

		this.action= action;
	}

	synchronized void set_connected(boolean connected){

		this.connected = connected;
	}

	synchronized void set_game(Game game){

		this.game = game;
	}

	float[] get_curr_pos(){

		try{

			return this.game.jogadores.get(this.username).jogador.pos;
		}
		catch(Exception e){

			return new float[]{0.0f, 0.0f};
		}
	}

	void mouseClicked(float x, float y){

		this.set_action(this.menu.mouseClicked(x, y, this));
	}

	void keyReleased(char c){}

	void keyPressed(char c){

		if(this.menu.writing){

			if(this.menu.keyPressed(c)){

				if(this.username.length() == 0){

					this.username = this.menu.get_word(this.menu.curr).palavra;
				}
				else if(this.username.length() > 0){

					this.password = this.menu.get_word(this.menu.curr).palavra;
					this.send = true;
					this.menu.writing = false;
					notifyAll();
				}

				this.menu.get_word(this.menu.curr).palavra = "";
			}
		}
	}

	synchronized void send_info(){

		while(!this.send){

			try{

				wait();
			}
			catch(Exception e){

				System.out.println("Wait failed");
			}
		}

		this.send = false;

		try{
			String message = "";

			if(!this.action.equals("update")){

				message = this.action + "," + username + "," + password;
				// System.out.println("message: " + message);
				this.action = "";
			}
			else{

				this.send = true;

				this.set_vector(new float[]{mouseX - this.get_curr_pos()[0], mouseY - this.get_curr_pos()[1]});
				
				// System.out.println("mouse: " + mouseX + ", " + mouseY);
				
				if (mouseButton == LEFT){
					
					message = this.action + "," + (float) mouseX + "," + (float) mouseY + "," + "boost";
				}
				else{

					if(this.prevMouseX != mouseX || this.prevMouseY != mouseY){

						message = this.action + "," + (float) mouseX + "," + (float) mouseY + "," + "notboost";
					}
				}
			}

			out.println(message);
			out.flush();
		}
		catch(Exception e){

			System.out.println("Couldn't send info: " + e);
		}
	}

	void receive_info(){

		try{

			String res = in.readLine();
			// System.out.println("res: " + res);
			synchronized(this){

				switch(res){

					case "changed":
					this.playing = false;
					System.out.println("Changed menu");
					// this.send = true;
					// notifyAll();
					break;

					case "created":
					System.out.println("Conta Criada");
					break;

					case "closed":
					System.out.println("Conta Eliminada");
					break;

					case "in":
					this.is_online = true;
					break;

					case "out":
					this.is_online = false;
					break;

					case "exists":
					System.out.println("Conta já existe");
					break;

					case "ready":
					System.out.println("startei");
					this.playing = true;
					this.send = true;
					this.action = "update";
					notifyAll();
					break;
				}

				if (this.playing && res.split(",", 2)[0].equals("update")){

					this.game.state_parser(res.split(",", 2)[1]);
				}

				else if (res.split(",", 2)[0].equals("leaders")){

					this.menu.leaderboard(res.split(",", 2)[1]);
					this.playing = false;
				}
			}
		}
		catch(Exception e){}
	}
}

class Sock_writer extends Thread{
	
	Client cliente;

	Sock_writer(){

		this.cliente = new Client();
	}

	Sock_writer(Client cliente){

		this.cliente = cliente;
	}

	void run(){
		try{
			while(true){
				
				this.cliente.send_info();
				sleep(1);
			}
		}catch(InterruptedException e){}
	}
}

class Sock_reader extends Thread{
	
	Client cliente;

	Sock_reader(){

		this.cliente = new Client();
	}

	Sock_reader(Client cliente){

		this.cliente = cliente;
	}

	void run(){

		while(true){

			this.cliente.receive_info();
		}
	}
}