class Game{

	HashMap<String, Player> jogadores;
	ArrayList<Crystal> cristais;
	float zona;

	Game(){

		this.jogadores = new HashMap<String, Player>();
		this.cristais = new ArrayList<Crystal>();
		this.zona = (float)Math.sqrt((1024.0f * 1024.0f) + (800.0f * 800.0f));
	}

	Game(HashMap<String, Player> jogadores, ArrayList<Crystal> cristais){

		this.jogadores = jogadores;
		this.cristais = cristais;
		this.zona = (float)Math.sqrt((1024.0f * 1024.0f) + (800.0f * 800.0f));
	}

	void draw_game(Client c){

		for (Map.Entry<String, Player> jogador : this.jogadores.entrySet()){

			strokeWeight(1);
			if(c.username.equals(jogador.getKey())){

				line(c.get_curr_pos()[0], c.get_curr_pos()[1], mouseX, mouseY);
				strokeWeight(6);
				jogador.getValue().draw_player();
			}
			else{

				jogador.getValue().draw_player();
			}
		}

		strokeWeight(1);

		for (Crystal cristal : this.cristais){

			cristal.draw_crystal();
		}

		noFill();
		circle(512, 400, this.zona);

	}

	void state_parser(String info){

		this.zona = Float.parseFloat(info.split(",", 2)[0]);
		info = info.split(",", 2)[1];

		this.jogadores.clear();
		this.cristais.clear();

		JSONObject obj = parseJSONObject(info);

		JSONArray array = obj.getJSONArray("players");

		for(int j = 0; j < array.size(); j++){

			JSONObject i = array.getJSONObject(j);
			i = i.getJSONObject("player");
			String name = i.getString("username");
			float[] pos = new float[]{i.getJSONArray("pos").getFloat(0), i.getJSONArray("pos").getFloat(1)};
			color cor = color(i.getJSONArray("color").getFloat(0), i.getJSONArray("color").getFloat(1), i.getJSONArray("color").getFloat(2));
			float mass = (float) i.getFloat("mass");
			Circle_shape aux = new Circle_shape(pos, mass, cor);
			Player p = new Player(aux);
			this.jogadores.put(name, p);
		}

		array = obj.getJSONArray("crystals");

		for(int j = 0; j < array.size(); j++){

			JSONObject i = array.getJSONObject(j);
			i = i.getJSONObject("crystal");
			float mass = (float) i.getFloat("mass");
			float[] pos = new float[]{i.getJSONArray("pos").getFloat(0), i.getJSONArray("pos").getFloat(1)};
			color cor = color(i.getJSONArray("color").getFloat(0), i.getJSONArray("color").getFloat(1), i.getJSONArray("color").getFloat(2));
			Circle_shape aux = new Circle_shape(pos, mass, cor);
			Crystal c = new Crystal(aux);
			this.cristais.add(c);
		}
	}
}

class Player{

	Circle_shape jogador;

	Player(){

		this.jogador = new Circle_shape();
	}

	Player(Circle_shape jogador){

		this.jogador = jogador;
	}

	void draw_player(){

		this.jogador.draw_shape();
	}
}

class Crystal{

	Circle_shape cristal;

	Crystal(){

		this.cristal = new Circle_shape();
	}

	Crystal(Circle_shape cristal){

		this.cristal = cristal;
	}

	void draw_crystal(){

		this.cristal.draw_shape();
	}
}