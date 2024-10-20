// netstat -p tcp -na | findstr 12345
import java.io.*;
import java.net.*;

Client cliente;
Menu menu;

void setup(){

	rectMode(RADIUS);
	size(1024, 800);
	frameRate(60);
	cliente = new Client("localhost", 12345, "", "", "");
	menu = new Menu();
	menu.distr_row(new float[]{250.0f, 200.0f}, 70.0f, 50.0f, color(12, 12, 12), 35.0f, 10.0f, color(255, 255, 255), 20, "Candara-Light-40.vlw", 5, 1024, 800, new String[]{"Sign in", "Login", "Delete", "Play", "Logout"});
	synchronized(cliente){

		cliente.menu = menu;
	}
}

void draw(){

	clear();
	background(255);

	if(!cliente.playing){

		synchronized(cliente){

			cliente.menu.draw_menu();
		}
	}
	else{

		synchronized(cliente){

			cliente.game.draw_game(cliente);
		}
	}
}

void mouseClicked(){

	if(!cliente.playing){

		synchronized(cliente){

			cliente.mouseClicked(mouseX, mouseY);
		}
	}
}

void mouseReleased() {}

void keyReleased(){

	if(!cliente.playing){

		synchronized(cliente){

			cliente.keyReleased(key);
		}
	}
}

void keyPressed(){

	if(!cliente.playing){

		synchronized(cliente){

			cliente.keyPressed(key);
		}
	}
}