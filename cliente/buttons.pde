class Button{

	Rectangle_shape forma;
	Words palavra;

	Button(){

		this.forma = new Rectangle_shape();
		this.palavra = new Words();
	}

	Button(float[] pos, float largura, float altura, color cor, String palavra,  float larg_caixa, float alt_caixa, color cor_palavra, int tamanho, String fonte){

		this.forma = new Rectangle_shape(pos, largura, altura, cor);
		this.palavra = new Words(pos, palavra, larg_caixa, alt_caixa, cor_palavra, tamanho, fonte);
	}

	void draw_button(){

		this.forma.draw_shape();
		this.palavra.draw_word();
	}

	void change_rec_color(color cor){

		this.forma.cor = cor;
	}

	void change_word_color(color cor){

		this.palavra.cor = cor;
	}

	String get_word(){

		return this.palavra.palavra;
	}
}

class Row{

	Words jogador;
	Words vitorias;

	Row(){

		this.jogador = new Words();
		this.vitorias = new Words();
	}

	Row(String nome, String vit, int pos, float i){

		this.jogador = new Words(new float[]{700.0f, i}, "position:  " + pos + "    " + nome, 200.0f, 20.0f, color(0, 0, 0), 15, "Candara-Light-40.vlw");
		this.vitorias = new Words(new float[]{800.0f, i}, vit, 200.0f, 20.0f, color(0, 0, 0), 15, "Candara-Light-40.vlw");
	}

	void draw_row(){

		this.jogador.draw_word();
		this.vitorias.draw_word();
	}
}

class Menu{

	ArrayList<Button> botoes;
	ArrayList<Words> palavras;
	ArrayList<Row> leaderboard;

	int curr;
	boolean writing;
	boolean print_temp_mes;

	Menu(){

		this.botoes = new ArrayList<Button>();
		this.palavras = new ArrayList<Words>();
		this.leaderboard = new ArrayList<Row>();
		this.curr = -1;
	}

	Menu(ArrayList<Button> botoes, ArrayList<Words> palavras, ArrayList<Row> leaderboard, int curr, String action){

		this.botoes = botoes;
		this.palavras = palavras;
		this.leaderboard = leaderboard;
		this.curr = curr;
	}

	void create_button(float[] pos, float largura, float altura, color cor, String palavra,  float larg_caixa, float alt_caixa, color cor_palavra, int tamanho, String fonte){

		Button bot = new Button(pos, largura, altura, cor, palavra, larg_caixa, alt_caixa, cor_palavra, tamanho, fonte);
		this.botoes.add(bot);
	}

	void create_word(float[] pos, String palavra, float largura, float altura, color cor, int tamanho, String fonte){

		Words pal = new Words(pos, palavra, largura, altura, cor, tamanho, fonte);
		this.palavras.add(pal);
	}

	void draw_menu(){

		for (Button botao : this.botoes){

			botao.draw_button();
		}

		for (Words palavra : this.palavras){

			palavra.draw_word();
		}

		for (Row linha : this.leaderboard){

			linha.draw_row();
		}
	}

	void distr_row(float[] pos, float largura, float altura, color cor, float larg_caixa, float alt_caixa, color cor_palavra, int tamanho, String fonte, int num_bots, int x, int y, String[] pals){

		float calc = ((float) y) / ((float) num_bots + 1);

		for (int i = 1; i <= num_bots; i++){
			
			Button temp = new Button(new float[]{pos[0], calc * i}, largura, altura, cor, pals[i - 1], larg_caixa, alt_caixa, cor_palavra, tamanho, fonte);
			this.botoes.add(temp);

			float[] new_pos = new float[]{pos[0] + largura + 100.0f, calc * i};
			Words w = new Words(new_pos, "", 45.0f, 20.0f, color(0, 0, 0), 15, "Candara-Light-40.vlw");
			this.palavras.add(w);
		}
	}

	// {}
	void leaderboard(String info){


		this.leaderboard.clear();
		// System.out.println("info: " + info);
		String[] temp = info.split(",", -1);
		// System.out.println("temp: " + temp);
		float pos = 150.0f;

		for (int i = 0; i < temp.length && i < 5; i++) {

			String[] t = temp[i].substring(1, temp[i].length() - 1).split(";", -1);
			// System.out.println("t: " + t);

			Row row = new Row(t[0], t[1], i + 1, pos);
			this.leaderboard.add(row);
			pos += 30.0f;
		}
	}

	String get_but_word(int value){

		return this.botoes.get(value).get_word();
	}

	Button get_button(int value){

		return this.botoes.get(value);
	}

	Words get_word(int value){

		return this.palavras.get(value);
	}

	String mouseClicked(float mouseX, float mouseY, Client c){

		String action = "";
		int i = 0;

		if(!this.writing){
			
			if (mouseButton == LEFT){

				for (Button b : this.botoes){

					if (b.forma.inside_bounds(new float[]{mouseX, mouseY})){

						switch (b.get_word()){

							case "Sign in":
							if(!c.is_online){
								c.username = "";
								c.password = "";
								action = "create";
								this.writing = true;
								this.curr = i;
							}
							else{

								System.out.println("You are logged In");
							}
							break;

							case "Login":
							if(!c.is_online){
								c.username = "";
								c.password = "";
								action = "login";
								this.writing = true;
								this.curr = i;
							}
							else{
								System.out.println("Already logged in");
							}
							break;

							case "Play":
							if(c.is_online){

								action = "play";
								// c.playing = true;
								c.send = true;
								c.notifyAll();
							}
							else{

								System.out.println("Not logged in yet");
							}
							break;

							case "Logout":
							if(c.is_online){

								action = "logout";
								c.send = true;
								c.notifyAll();
							}
							else{

								System.out.println("Not logged in yet");
							}
							break;

							case "Delete":
							c.username = "";
							c.password = "";
							action = "close";
							this.writing = true;
							this.curr = i;
							break;

							default:
							break;
						}
					}

					i += 1;
				}
			}
		}

		return action;
	}

	boolean keyPressed(char c){

		return this.get_word(this.curr).key_pressed(c);
	}
}