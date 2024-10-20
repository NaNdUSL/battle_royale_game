import java.util.*;
import java.lang.Math;

class Rectangle_shape{

	float []pos;
	float largura;
	float altura;
	color cor;

	Rectangle_shape(){

		this.pos = new float[] {1, 1};
		this.largura = 1;
		this.altura = 1;
		this.cor = color(100, 100, 100);
	}

	Rectangle_shape(float[] pos, float largura, float altura, color cor){

		this.pos = pos;
		this.largura = largura;
		this.altura = altura;
		this.cor = cor;
	}

	void draw_shape(){

		fill(this.cor);
		rect(this.pos[0], this.pos[1], this.largura, this.altura);
	}

	boolean inside_bounds(float[] pos){

		if (pos[0] >= this.pos[0] - this.largura && pos[0] < this.pos[0] + this.largura && pos[1] >= this.pos[1] - this.altura && pos[1] < this.pos[1] + this.altura){

			return true;
		}
		else return false;
	}
}

class Circle_shape{

	float[] pos;
	float raio;
	color cor;

	Circle_shape(){

		this.pos = new float[] {1, 1};
		this.raio = 1;
		this.cor = color(100, 100, 100);
	}

	Circle_shape(float []pos, float raio, color cor){

		this.pos = pos;
		this.raio = raio;
		this.cor = cor;
	}

	void draw_shape(){

		fill(this.cor);
		circle(this.pos[0], this.pos[1], this.raio);
	}

	boolean inside_bounds(float[] pos){

		if (Math.abs(this.pos[0] - pos[0]) + Math.abs(this.pos[1] - pos[1]) <= this.raio){

			return true;
		}
		else return false;
	}
}

class Words{

	float[] pos;
	float largura;
	float altura;
	String palavra;
	color cor;
	int tamanho;
	PFont fonte;

	Words(){

		this.pos = new float []{1.0f, 1.0f};
		this.largura = 1.0f;
		this.altura = 1.0f;
		this.palavra = "Default";
		this.cor = color(255, 255, 255);
		this.tamanho = 20;
		this.fonte = loadFont("Candara-Light-40.vlw");
	}

	Words(float[] pos, String palavra, float largura, float altura, color cor, int tamanho, String fonte){

		this.pos = pos;
		this.largura = largura;
		this.altura = altura;
		this.palavra = palavra;
		this.cor = cor;
		this.tamanho = tamanho;
		this.fonte = loadFont(fonte);
	}

	void draw_word(){

		textFont(this.fonte);
		fill(this.cor);
		textSize(this.tamanho);
		text(this.palavra, this.pos[0], this.pos[1], this.largura, this.altura);
	}

	boolean key_pressed(char key){

		boolean ret = false;

		if (key == ENTER){

			ret = true;
		}
		else if (key == BACKSPACE && this.palavra.length() > 0){

			this.palavra = this.palavra.substring(0, this.palavra.length() - 1);
		}
		else if ((key > 47 && key < 57) || (key > 64 && key < 91) || (key>96 && key < 123)){

			this.palavra += key;
		}

		return ret;
	}
}
