import processing.serial.*;    // Importing the serial library to communicate with the Arduino 
import processing.sound.*;
import java.util.Iterator;
import java.util.HashMap;
import java.util.Map;
import java.util.ArrayList;
import javax.swing.JFrame;

Serial myPort;
float inByte = 0;
float bmpVal;
float bmpInit = -1;

SoundFile file;
String audioName = "music.mp3";
String path;

StopWatchTimer timer = new StopWatchTimer();

String typing = "";
String savedDur = "";
String savedPow = "";
float duration = -1;
int power = -1;
int wellDone = 0;

float background_color ;   // Variable for changing the background color

int x = 40;           // X position
int y = 60;//83;          // Y position
int columns= 15;    // Number of tile columns
int rows= 14;       // Number of tile rows
int tilewidth = 40;  // Visual width of a tile
int tileheight = 40; // Visual height of a tile
int rowheight = 40;//34;  // Height of a row
int radius= 20;     // Bubble collision radius
int width1 = 0;
int height1 = 0;      // Height, gets calculated

// Number of different colors
int bubblecolors = 7;

// Game states
int init = 0;
int ready = 1;
int shootbubble = 2;
int removecluster = 3;
int gameover = 4;
int win = 5;

int gamestate = init;

int score = 0;
int turncounter = 0;
int rowoffset = 0;
int animationstate = 0;
int animationtime = 0;

int[][][] neighborsoffsets = {{{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}},
            {{1, 0}, {1, 1}, {0, 1}, {-1, 0}, {0, -1}, {1, -1}}};
            
int[][] colors = {{255,0,0}, {0,255,0},{0,0,255},{255,255,0},{255,0,255},{0,153,255},{255,255,255}};

boolean showcluster = false;
boolean firstRowShifted = false;
boolean settings = true;
boolean instructions = false;
ArrayList<Tile> cluster = new ArrayList<Tile>();
ArrayList<ArrayList<Tile>> floatingclusters = new ArrayList<ArrayList<Tile>>();

Tile[][] tiles = new Tile[columns][rows];
Player player = new Player();
PImage bubbleimage;

class Tile {
  float x;
  float y;
  int type;
  boolean removed;
  int shift;
  int velocity;
  int alpha;
  boolean processed;
  
  Tile(float x, float y, int type, int shift){
        this.x = x;
        this.y = y;
        this.type = type;
        this.removed = false;
        this.shift = shift;
        this.velocity = 0;
        this.alpha = 1;
        this.processed = false;
    };
}

class Bubble{
  float x;
  float y;
  double angle;
  int speed;
  int dropspeed;
  int tiletype;
  boolean visible;
  
  Bubble(float x, float y, double angle, int speed, int dropspeed, int tiletype, boolean visible){
    this.x=x;
    this.y=y;
    this.angle=angle;
    this.speed=speed;
    this.dropspeed=dropspeed;
    this.tiletype=tiletype;
    this.visible=visible;
  }
}


class Player{
  int x = 0;
  int y = 0;
  double angle = 0;
  int tiletype = 0;
  Bubble bubble = new Bubble(0, 0, 0, 1000, 900, 0, false);
  Bubble nextbubble = new Bubble(0, 0, 0, 0, 0, 0, false);
}

class StopWatchTimer {
  int startTime = 0, stopTime = 0;
  boolean running = false;  
  
  void start() {
      startTime = millis();
      running = true;
  }
  
  void stop() {
      stopTime = millis();
      running = false;
  }
  
  int getElapsedTime() {
      int elapsed;
      if (running) {
           elapsed = (millis() - startTime);
      }
      else {
          elapsed = (stopTime - startTime);
      }
      return elapsed;
  }
  
  int second() {
    return (getElapsedTime() / 1000) % 60;
  }
}

void update() {
    if (gamestate == ready) {
        // Game is ready for player input
    } else if (gamestate == shootbubble) {
        // Bubble is moving
        stateShootBubble(0.2);
    } else if (gamestate == removecluster) {
        // Remove cluster and drop tiles
        stateRemoveCluster(0.03);
    }
}

void setGameState(int newgamestate) { 
    gamestate = newgamestate;
    animationstate = 0;
    animationtime = 0;
}


void stateShootBubble(float dt) {
    // Bubble is moving
    // Move the bubble in the direction of the mouse
    player.bubble.x += 10 * Math.cos(degToRad(player.bubble.angle));
    player.bubble.y -= 10 * Math.sin(degToRad(player.bubble.angle));
    
    // Handle left and right collisions with the level
    if (player.bubble.x <= x) {
        // Left edge
        player.bubble.angle = 180 - player.bubble.angle;
        player.bubble.x = x;
    } else if (player.bubble.x + tilewidth >= width) {
        // Right edge
        player.bubble.angle = 180 - player.bubble.angle;
        player.bubble.x = x + width1 - tilewidth;
    }
 
    // Collisions with the top of the level
    if (player.bubble.y <= y) {
        // Top collision
        player.bubble.y = y;
        snapBubble();
        return;
    }
    
    // Collisions with other tiles
    for (int i=0; i<columns; i++) {
        for (int j=0; j<rows; j++) {
            Tile tile = tiles[i][j];
            // Skip empty tiles
            if (tile.type < 0) {
                continue;
            }
            
            // Check for intersections
            int tilex = getTileX(i, j);
            int tiley = getTileY(i, j);

            if (circleIntersection(player.bubble.x, player.bubble.y,
                                   radius, tilex, tiley, radius)) {
                // Intersection with a level bubble
                snapBubble();
                return;
            }
        }
    }
}

void stateRemoveCluster(float dt) {
    if (animationstate == 0) {
        resetRemoved();
        
        // Mark the tiles as removed
        for (int i=0; i<cluster.size(); i++) {
            // Set the removed flag
            cluster.get(i).removed = true;
        }
        
        // Add cluster score
        score += cluster.size() * 100;
        
        // Find floating clusters
        floatingclusters = findFloatingClusters();
        
        if (floatingclusters.size() > 0) {
            // Setup drop animation
            for (int i=0; i<floatingclusters.size(); i++) {
                for (int j=0; j<floatingclusters.get(i).size(); j++) {
                    Tile tile = floatingclusters.get(i).get(j);
                    tile.shift = 0;
                    tile.shift = 1;
                    tile.velocity = player.bubble.dropspeed;
                    score += 100;
                }
            }
        }
        animationstate = 1;
    }
    
    if (animationstate == 1) {
        // Pop bubbles
        boolean tilesleft = false;
        for (int i=0; i<cluster.size(); i++) {
            Tile tile = cluster.get(i);
            
            if (tile.type >= 0) {
                tilesleft = true;
                // Alpha animation
                //tile.alpha -= dt * 15;
                //if (tile.alpha < 0) {
                //    tile.alpha = 0;
                //}

                //if (tile.alpha == 0) {
                    tile.type = -1;
                //    tile.alpha = 1;
                //}
            }                
        }
        
        // Drop bubbles
        for (int i=0; i<floatingclusters.size(); i++) {
            for (int j=0; j<floatingclusters.get(i).size(); j++) {
                Tile tile = floatingclusters.get(i).get(j);
                if (tile.type >= 0) {
                    tilesleft = true;
                    // Accelerate dropped tiles
                    tile.velocity += dt * 700;
                    tile.shift += dt * tile.velocity;  
                    // Alpha animation
                    tile.alpha -= dt * 8;
                    if (tile.alpha < 0) {
                        tile.alpha = 0;
                    }
                    // Check if the bubbles are past the bottom of the level
                    if (tile.alpha == 0 || (tile.y * rowheight + tile.shift > (rows - 1) * rowheight + tileheight)) {
                        tile.type = -1;
                        tile.shift = 0;
                        tile.alpha = 1;
                    }
                }
            }
        }
        if (!tilesleft) {
            // Next bubble
            nextBubble();
            // Check for game over
            boolean tilefound = false;
            for (int i=0; i<columns; i++) {
                for (int j=0; j<rows; j++) {
                    if (tiles[i][j].type != -1) {
                        tilefound = true;
                        break;
                    }
                }
            }
            if (tilefound) {
                setGameState(ready);
            } else {
                // No tiles left, game over
                setGameState(win);
            }
        }
    }
}


void snapBubble() {
    // Get the grid position
    float centerx = player.bubble.x;// + tilewidth/2;
    float centery = player.bubble.y;// + tileheight/2;
    int[] gridpos = getGridPosition(centerx, centery);

    // Make sure the grid position is valid
    if (gridpos[0] < 0) {
        gridpos[0] = 0;
    }
    if (gridpos[0] >= columns) {
        gridpos[0] = columns - 1;
    }
    if (gridpos[1] < 0) {
        gridpos[1] = 0;
    }
    if (gridpos[1] >= rows) {
        gridpos[1] = rows - 1;
    }
    // Check if the tile is empty
    boolean addtile = false;
    if (tiles[gridpos[0]][gridpos[1]].type != -1) {
        if (tiles[gridpos[0]-1][gridpos[1]-1].type == -1) {
          gridpos[0] -= 1;
          gridpos[1] -=1;
          addtile = true;
        }
        else if (tiles[gridpos[0]-1][gridpos[1]+1].type == -1) {
          gridpos[0] -= 1;
          gridpos[1] +=1;
          addtile = true;
        }
        else {
        // Tile is not empty, shift the new tile downwards
        for (int newrow=gridpos[1]+1; newrow<rows; newrow++) {
            if (tiles[gridpos[0]][newrow].type == -1) {
                gridpos[1] = newrow;
                addtile = true;
                break;
            }
        }
        }
    } else {
        addtile = true;
    }

    // Add the tile to the grid
    if (addtile) {
        // Hide the player bubble
        player.bubble.visible = false;
        // Set the tile
        tiles[gridpos[0]][gridpos[1]].type = player.bubble.tiletype;
        // Check for game over
        if (checkGameOver()) {
            return;
        }
        // Find clusters
        cluster = findCluster(gridpos[0], gridpos[1], true, true, false);
        if (cluster.size() >= 3) {
            wellDone = 20;
            textSize(20);
            text("Well Done!", width - 150, height - 200);
            fill(0);
            // Remove the cluster
            setGameState(removecluster);
            return;
         
        }
    }
    
    // No clusters found
    turncounter++;
    if (turncounter >= 5) {
        // Add a row of bubbles
        addBubbles();
        turncounter = 0;
        rowoffset = (rowoffset + 1) % 2;
        firstRowShifted = !firstRowShifted;
        if (checkGameOver()) {
            return;
        }
    }
    // Next bubble
    nextBubble();
    setGameState(ready);
}


boolean checkGameOver() {
    // Check for game over
    for (int i=0; i< columns; i++) {
        // Check if there are bubbles in the bottom row
        if (tiles[i][rows-1].type != -1) {
            // Game over
            nextBubble();
            setGameState(gameover);
            return true;
        }
    }
    return false;
}

void addBubbles() {
    // Move the rows downwards
    for (int i=0; i<columns; i++) {
        for (int j=0; j<rows-1; j++) {
            tiles[i][rows-1-j].type = tiles[i][rows-1-j-1].type;
        }
    }
    // Add a new row of bubbles at the top
    for (int i=0; i<columns; i++) {
        // Add random, existing, colors
        tiles[i][0].type = getExistingColor();
    }
}

ArrayList<Integer> findColors() {
    ArrayList<Integer> foundcolors = new ArrayList<>();
    boolean[] colortable = new boolean[bubblecolors];
    for (var i=0; i<bubblecolors; i++) {
        colortable[i] = false;
    }
    // Check all tiles
    for (int i=0; i<columns; i++) {
        for (int j=0; j<rows; j++) {
            Tile tile = tiles[i][j];
            if (tile.type >= 0) {
                if (!colortable[tile.type]) {
                    colortable[tile.type] = true;
                    foundcolors.add(tile.type);
                }
            }
        }
    }
    
    return foundcolors;
}

// Find cluster at the specified tile location
ArrayList<Tile> findCluster(int tx, int ty, boolean matchtype, boolean reset, boolean skipremoved) {
    // Reset the processed flags
    if (reset) {
        resetProcessed();
    }
    // Get the target tile. Tile coord must be valid.
    Tile targettile = tiles[tx][ty];
    
    // Initialize the toprocess array with the specified tile
    ArrayList<Tile> toprocess = new ArrayList<Tile>();
    toprocess.add(targettile);
    targettile.processed = true;
    ArrayList<Tile> foundcluster = new ArrayList<Tile>();

    while (toprocess.size() > 0) {
        // Pop the last element from the array
        Tile currenttile = toprocess.get(toprocess.size()-1);
        toprocess.remove(toprocess.size()-1);
        
        // Skip processed and empty tiles
        if (currenttile.type == -1) {
            continue;
        }
        
        // Skip tiles with the removed flag
        if (skipremoved && currenttile.removed) {
            continue;
        }
        
        // Check if current tile has the right type, if matchtype is true
        if (!matchtype || (currenttile.type == targettile.type)) {
            // Add current tile to the cluster
            foundcluster.add(currenttile);
            
            // Get the neighbors of the current tile
            ArrayList<Tile> neighbors = getNeighbors(currenttile);
            
            // Check the type of each neighbor
            for (int i=0; i<neighbors.size(); i++) {
                if (!neighbors.get(i).processed) {
                    // Add the neighbor to the toprocess array
                    toprocess.add(neighbors.get(i));
                    neighbors.get(i).processed = true;
                }
            }
        }
    }
    // Return the found cluster
    return foundcluster;
}


// Find floating clusters
ArrayList<ArrayList<Tile>> findFloatingClusters() {
    // Reset the processed flags
    resetProcessed();
    ArrayList<ArrayList<Tile>> foundclusters = new ArrayList<ArrayList<Tile>>();
    // Check all tiles
    for (int i=0; i<columns; i++) {
        for (int j=0; j<rows; j++) {
            Tile tile = tiles[i][j];
            if (!tile.processed) {
                // Find all attached tiles
                ArrayList<Tile> foundcluster = findCluster(i, j, false, false, true);
                // There must be a tile in the cluster
                if (foundcluster.size() <= 0) {
                    continue;
                }
                // Check if the cluster is floating
                boolean floating = true;
                for (int k=0; k<foundcluster.size(); k++) {
                    if (foundcluster.get(k).y == 0) {
                        // Tile is attached to the roof
                        floating = false;
                        break;
                    }
                }
                if (floating) {
                    // Found a floating cluster
                    foundclusters.add(foundcluster);
                }
            }
        }
    }
    return foundclusters;
}


// Reset the processed flags
void resetProcessed() {
    for (int i=0; i<columns; i++) {
        for (int j=0; j<rows; j++) {
            tiles[i][j].processed = false;
        }
    }
}
    
// Reset the removed flags
void resetRemoved() {
    for (int i=0; i<columns; i++) {
        for (int j=0; j<rows; j++) {
            tiles[i][j].removed = false;
        }
    }
}
    
// Get the neighbors of the specified tile
ArrayList<Tile> getNeighbors(Tile tile) {
    int tilerow = (int) (tile.y + rowoffset) % 2; // Even or odd row
    ArrayList<Tile> neighbors = new ArrayList<Tile>();
    
    // Get the neighbor offsets for the specified tile
    int[][] n = neighborsoffsets[tilerow];
    
    // Get the neighbors
    for (int i=0; i<n.length; i++) {
        // Neighbor coordinate
        int nx = (int) (tile.x + n[i][0]);
        int ny = (int) (tile.y + n[i][1]);
        
        // Make sure the tile is valid
        if (nx >= 0 && nx < columns && ny >= 0 && ny < rows) {
            neighbors.add(tiles[nx][ny]);
        }
    }
    
    return neighbors;
}

int getTileX(int column, int row) {
  int tilex = x + column * tilewidth + radius;

  // X offset for odd or even rows
  if ((row + rowoffset) % 2 != 0) {
      tilex += tilewidth/2;
  }
  return tilex;
}

int getTileY(int column, int row){
  int tiley = y + row * tileheight + radius;
  return tiley;
}


int[] getGridPosition(float x2, float y2) {
    double gridy = Math.floor((y2 - y) / rowheight);
    
    // Check for offset
    int xoffset = 0;
    if ((firstRowShifted && gridy % 2 == 0) || 
       (!firstRowShifted && gridy % 2 != 0)) {
        xoffset = tilewidth / 2;
    }
    double gridx = Math.floor((x2 - xoffset - x) / tilewidth);
    int[] result = {(int) gridx, (int) gridy};
    
    return result;
}

    
// Start a new game
void newGame() {
    score = 0;
    turncounter = 0;
    rowoffset = 0;
    setGameState(ready);
    createLevel();

    // Init the next bubble and set the current bubble
    nextBubble();
    nextBubble();
}


// Create a random level
void createLevel() {
    // Create a level with random tiles
    for (int j=0; j<rows; j++) {
        int randomtile = randRange(0, bubblecolors-1);
        int count = 0;
        for (int i=0; i<columns; i++) {
            if (count >= 2) {
                // Change the random tile
                int newtile = randRange(0, bubblecolors-1);
                
                // Make sure the new tile is different from the previous tile
                if (newtile == randomtile) {
                    newtile = (newtile + 1) % bubblecolors;
                }
                randomtile = newtile;
                count = 0;
            }
            count++;
            if (j < rows/2) {
                tiles[i][j].type = randomtile;
            } else {
                tiles[i][j].type = -1;
            }
        }
    }
}


void nextBubble() {
    // Set the current bubble
    player.tiletype = player.nextbubble.tiletype;
    player.bubble.tiletype = player.nextbubble.tiletype;
    player.bubble.x = player.x;
    player.bubble.y = player.y;
    player.bubble.visible = true;
    
    // Get a random type from the existing colors
    var nextcolor = getExistingColor();
    
    // Set the next bubble
    player.nextbubble.tiletype = nextcolor;
}

int getExistingColor() {
    ArrayList<Integer> existingcolors = findColors();
    
    var bubbletype = 0;
    if (existingcolors.size() > 0) {
        bubbletype = existingcolors.get(randRange(0, existingcolors.size()-1));
    }
    
    return bubbletype;
}


// Get a random int between low and high, inclusive
int randRange(int low, int high) {
    return (int) Math.floor(low + Math.random()*(high-low+1));
}

// Shoot the bubble
void shootBubble() {
    // Shoot the bubble in the direction of the mouse
    player.bubble.x = player.x;
    player.bubble.y = player.y;
    player.bubble.angle = player.angle;
    player.bubble.tiletype = player.tiletype;

    // Set the gamestate
    setGameState(shootbubble);
}

// Check if two circles intersect
boolean circleIntersection(float x1, float y1, int r1, int x2, int y2, int r2) {
    // Calculate the distance between the centers
    float dx = x1 - x2;
    float dy = y1 - y2;
    double len = Math.sqrt(dx * dx + dy * dy);
    
    if (len < r1 + r2) {
        // Circles intersect
        return true;
    }
    return false;
}

// Convert radians to degrees
double radToDeg(double angle) {
    return angle * (180 / Math.PI);
}

// Convert degrees to radians
double degToRad(double angle) {
    return angle * (Math.PI / 180);
}

//void mouseMoved() {
//      // Get the mouse position
//    int x = mouseX;
//    int y = mouseY;

//    // Get the mouse angle
//    double mouseangle = radToDeg(Math.atan2((player.y+tileheight/2) - y, x - (player.x+tilewidth/2)));

//    // Convert range to 0, 360 degrees
//    if (mouseangle < 0) {
//        mouseangle = 180 + (180 + mouseangle);
//    }

//    // Restrict angle to 8, 172 degrees
//    var lbound = 8;
//    var ubound = 172;
//    if (mouseangle > 90 && mouseangle < 270) {
//        // Left
//        if (mouseangle > ubound) {
//            mouseangle = ubound;
//        }
//    } else {
//        // Right
//        if (mouseangle < lbound || mouseangle >= 270) {
//            mouseangle = lbound;
//        }
//    }

//    // Set the player angle
//    player.angle = mouseangle;
//}

void mousePressed2() {
  // On mouse button click
//y = 60

  if (gamestate == ready) {
    gamestate = shootbubble;
    shootBubble();
  } else if (gamestate == gameover) {
    newGame();
  }
}

//void breath() {
//  if (gamestate == ready) {
//    gamestate = shootbubble;
//    shootBubble();
//  } else if (gamestate == gameover) {
//    newGame();
//  }
//}

// Draw text that is centered
void drawCenterText(String text) {
  surface.setTitle(text);
}

// Draw a frame around the game
void drawFrame() {
  String s = "Bubbles Game";
  fill(0, 153, 153);
  textSize(22);
  text(s, width1 / 2 - 20,0, width1, height1/8);
}
  
// Render tiles
void renderTiles() {
    // Top to bottom
    for (int j=0; j<rows; j++) {
        for (int i=0; i<columns; i++) {
            // Get the tile
            Tile tile = tiles[i][j];
            
            // Calculate the tile coordinates
            int tilex = getTileX(i, j);
            int tiley = getTileY(i, j);
            
            // Check if there is a tile present
            if (tile.type >= 0) {
                // Support transparency
                // Draw the tile using the color
                drawBubble(tilex, tiley, tile.type);
            }
        }
    }
}

// Draw the bubble
void drawBubble(float x1, float y1, int index) {
  if (index < 0 || index >= bubblecolors)
    return;
  noStroke();
  lights();
  translate(x1, y1, 0);
  fill(colors[index][0], colors[index][1], colors[index][2]);
  sphere(tilewidth / 2);
  translate(-x1,-y1,0);

}

// Render the game
void render() {
    // Draw the frame around the game
    //drawFrame();
    double yoffset =  tileheight/2;
    renderTiles();
    float scorex = x + width1 - 150;
    double scorey = y + height1 + tileheight - yoffset - 8;
    String s = "Score: ";
    fill(0, 153, 153);
    textSize(18);
    text(s, 20, (float) scorey - 60);
    String s2 = Integer.toString(score);
    text(s2, 100, (float) scorey - 60);
    // Render player bubble
    renderPlayer();
    //fill(0);
    //text("duration time [sec]: ", 20, (float) scorey - 40);
    //text(savedDur, 190, (float) scorey - 40);
    //text("breath pressure [hPa]: ", 20, (float) scorey - 20);
    //text(savedPow, 190, (float) scorey - 20);
}

// Render the player bubble
void renderPlayer() {
    float centerx = player.x;
    float centery = player.y;

    // Draw the angle
    stroke(0);
    //int cx, int cy, int len, float angle
    drawArrow((int)centerx,  (int)centery,  2.5*tilewidth,(float) -player.angle);
    //fillArrow(map(timer.getElapsedTime(), 0, duration*1000, 0, 2.5*tilewidth), (int)centerx,  (int)centery, (int) 2.5*tilewidth,(float) -player.angle);
    //line((float)(centerx + 1.5*tilewidth * Math.cos(degToRad(player.angle))), (float) (centery - 1.5*tileheight * Math.sin(degToRad(player.angle))), 0, centerx, centery, 0);
    
    // Draw the next bubble
    drawBubble(player.nextbubble.x, player.nextbubble.y, player.nextbubble.tiletype);
    
    // Draw the bubble
    if (player.bubble.visible) {
        drawBubble(player.bubble.x, player.bubble.y, player.bubble.tiletype);
    }
}


void serialEvent( Serial myPort) 
{
  String inString = myPort.readStringUntil('\n');
  int lbound = 20;
  int ubound = 160;
  if (inString!= null) {
    String[] nString = split(inString, ',');
    //convert to an int and map to the screen height:
    inByte = float(nString[0]);
    inByte = map(inByte, 0, 1023, lbound, ubound);
    if (bmpInit < 0) {
      bmpInit = float(nString[1]);
    }
    else {
      bmpVal = float(nString[1]) - bmpInit;
      //println(bmpVal);
    }
  }
    // Get the mouse angle
    double mouseangle = inByte;
    // Convert range to 0, 360 degrees
    if (mouseangle < 0) {
        mouseangle = 180 + (180 + mouseangle);
    }
    
    if (mouseangle > 90 && mouseangle < 270) {
        if (mouseangle > ubound) {
            mouseangle = ubound;
        }
    } else {
        if (mouseangle < lbound || mouseangle >= 270) {
            mouseangle = lbound;
        }
    }
    player.angle = mouseangle;
}

void breath() {
  if (gamestate == ready) {
    gamestate = shootbubble;
    shootBubble();
  } else if (gamestate == gameover) {
    newGame();
  }
}

boolean pressureCheck2() {
  if (bmpVal > power) {
   if (timer.running) {
     float centerx = player.x;
    float centery = player.y;
     
    if (timer.getElapsedTime() >= duration*1000) {
      timer.stop();
      return true;
    }
    println(map(timer.getElapsedTime(), 0, duration*1000.0, 0, 2.5*tilewidth));
     fillArrow(map(timer.getElapsedTime(), 0, duration*1000.0, 0, 2.5*tilewidth + 10), (int)centerx,  (int)centery, 2.5*tilewidth,(float) -player.angle);
    
   } else {
    timer.start(); 
   }
  }
  else {
    timer.stop();
  }
  return false;
}

boolean pressureCheck() {
  if (bmpVal > power) {
   if (timer.running) {
    if (timer.second() >= duration) {
      timer.stop();
      return true;
    }
   } else {
    timer.start(); 
   }
  }
  else {
    timer.stop();
  }
  return false;
}

void instructionsScreen() {
  noStroke();
  fill(0, 153, 153);
  rect(x, y, 700, 500);
  fill(0);
  textSize(70);
  text("Instructions", 200, y + 100);
  translate(350 + tilewidth, 500, 0);
  fill(255);
  sphere(tilewidth);
  translate(-25,12,100);
  fill(0);
  textSize(20);
  text("Thanks",-3,-4);
  translate(-(350 + tilewidth - 25), - 512, -100);
  translate(0,0,10);
  fill(0);
  textSize(17);
  String s = "Match at least three bubbles of the same color to pop them and clear them off the board.\n Mind your angles as you bounce bubbles off the wall to hit the hard-to-reach spots.\n Use lightning and sun bombs as boosts to clear whole sections, and thaw the ice\n blocks by clearing adjacent bubbles. Keep on popping until you run out of bubbles!";
  text(s, 100, height/2-100);
  translate(0,0,-10);
}


void settingsScreen() {
  translate(0,0,10);
  hs1.update();
  hs2.update();
  hs1.display();
  hs2.display();
  translate(0,0,-10); 
  duration = hs1.getTime(map(hs1.getPos(),0,220,0.5,5));
  power = (int) hs2.getPressure((int) map(hs2.getPos(),0,220,50,550));
  noStroke();
   
  fill(0, 153, 153);
  rect(x, y, 700, 500);
  fill(0);
  textSize(70);
  text("settings", 270, y + 100);
  translate(350 + tilewidth, 500, 0);
  fill(255);
  sphere(tilewidth);
  translate(-25,12,100);
  fill(0);
  textSize(40);
  text("OK",0,0);
  translate(-(350 + tilewidth - 25), - 512, -100);
  translate(0,0,10);
  fill(0);
  textSize(20);
  text("Duration [sec]:", 100, height/2-25);
  String d = Float.toString(duration);
  text(d, 230, height/2-25);
  text("Pressure [hPa]:", 100, height/2+35);
  String c = Integer.toString(power);
  text(c, 230, height/2+35);
  translate(0,0,-10);
}


void drawSettingsBubbles() {
  noStroke();
  lights();
  pushMatrix();
  translate(width - tilewidth*2.5, tilewidth * 3, 0);
  fill(0,153,153);
  sphere(tilewidth * 0.75);
  translate(-(width - tilewidth*2.5), -tilewidth*3, 0);
  popMatrix();
  translate(width - tilewidth*2.5, tilewidth * 5, 0);
  fill(105,205,205);
  sphere(tilewidth * 0.75);
  translate(-(width - tilewidth*2.5), -tilewidth * 5, 0);
  translate(width - tilewidth*2.5, tilewidth * 7, 0);
  fill(58,213,213);
  sphere(tilewidth * 0.75);
  translate(-(width - tilewidth*2.5), -tilewidth * 7, 0);
  drawSound();
  translate(width - tilewidth*2.5, tilewidth * 9, 0);
  fill(39,191,95);
  sphere(tilewidth * 0.75);
  translate(-(width - tilewidth*2.5), -tilewidth * 9, 0);
}

void drawArrow(int cx, int cy, float len, float angle){
  pushMatrix();
  translate(cx, cy);
  rotate(radians(angle));
  strokeWeight(8);
  line(0,0,len, 0);
  fill(0);
  noStroke();
  triangle(len+10,0, len-15, -15, len-15, 15);
  translate(-cx, -cy);
  popMatrix();
}

void fillArrow(float dur, int cx, int cy, float len, float angle) {
  pushMatrix();
  translate(cx, cy,10);
  rotate(radians(angle));
  strokeWeight(8);
  stroke(255);
  fill(255);
  line(0,0,dur, 0);
  stroke(100);
  fill(255,255,255);
  noStroke();
  if (dur >= len-15) {
    float dx = (dur - len - 10) / (25.0/15.0);
    fill(255);
    quad(len-15, -15, dur, dx, dur, -dx, len-15, 15 );
    fill(255,255,255);
  }
  translate(-cx, -cy,-10);
  popMatrix();
  
}

void drawSound() {
  pushMatrix();
  translate(-10,-2,500);
  fill(0);
  strokeWeight(8);
  rect(width - tilewidth*2.5 -13, tilewidth * 7-5, 14,14);
  float x1 = width - tilewidth*2.5 +1;
  float y1 = tilewidth * 7 + 9;
  point(50,50);
  fill(0);
  noStroke();
  quad(x1,y1,x1,y1-15,x1+15,y1-25,x1+15,y1+10);
  noFill();
  strokeWeight(2);
  stroke(50);
  arc(x1+5, y1-7.5,tilewidth,tilewidth, -QUARTER_PI, QUARTER_PI);
  arc(x1+5, y1-7.5,tilewidth+15,tilewidth+15, -QUARTER_PI, QUARTER_PI);
  translate(10,2,-500);
  popMatrix();
}


HScrollbar hs1, hs2;  // Two scrollbars
PImage img1, img2;  // Two images to load


class HScrollbar {
  int swidth, sheight;    // width and height of bar
  float xpos, ypos;       // x and y position of bar
  float spos, newspos;    // x position of slider
  float sposMin, sposMax; // max and min values of slider
  int loose;              // how loose/heavy
  boolean over;           // is the mouse over the slider?
  boolean locked;
  float ratio;

  HScrollbar (float xp, float yp, int sw, int sh, int l) {
    swidth = sw;
    sheight = sh;
    int widthtoheight = sw - sh;
    ratio = (float)sw / (float)widthtoheight;
    xpos = xp;
    ypos = yp-sheight/2;
    spos = xpos + swidth/2 - sheight/2;
    newspos = spos;
    sposMin = xpos;
    sposMax = xpos + swidth - sheight;
    loose = l;
  }
  
  float getTime(float x){
    if (x < 0.5){
      return 0;
    }
    if (x < 1){
      return 0.5;
    }
    if (x < 1.5){
      return 1;
    }
    if (x < 2){
      return 1.5;
    }
    if (x < 2.5){
      return 2;
    }
    if (x < 3){
      return 2.5;
    }
    if (x < 3.5){
      return 3;
    }
    if (x < 4){
      return 3.5;
    }
    if (x < 4.5){
      return 4;
    }
    if (x < 5){
      return 4.5;
    }
    return 5;
  }
  
  float getPressure(float x) {
    if (x < 100){
      return 50;
    }
    if (x < 150){
      return 100;
    }
    if (x < 200){
      return 150;
    }
    if (x < 250){
      return 200;
    }
    if (x < 300){
      return 250;
    }
    if (x < 350){
      return 300;
    }
    if (x < 400){
      return 350;
    }
    if (x < 450){
      return 400;
    }
    if (x < 500){
      return 450;
    }
    if (x < 550){
      return 500;
    }
    return 550;
  }
  
  void update() {
    if (overEvent()) {
      over = true;
    } else {
      over = false;
    }
    if (mousePressed && over) {
      locked = true;
    }
    if (!mousePressed) {
      locked = false;
    }
    if (locked) {
      newspos = constrain(mouseX-sheight/2, sposMin, sposMax);
    }
    if (abs(newspos - spos) > 1) {
      spos = spos + (newspos-spos)/loose;
    }
  }

  float constrain(float val, float minv, float maxv) {
    return min(max(val, minv), maxv);
  }

  boolean overEvent() {
    if (mouseX > xpos && mouseX < xpos+swidth &&
       mouseY > ypos && mouseY < ypos+sheight) {
      return true;
    } else {
      return false;
    }
  }

  void display() {
    noStroke();
    fill(204);
    rect(xpos, ypos, swidth, sheight);
    if (over || locked) {
      fill(0, 0, 0);
    } else {
      fill(102, 102, 102);
    }
    rect(spos, ypos, sheight, sheight);
  }

  float getPos() {
    return (int)(spos - xpos) * ratio;
  }
}


void keyPressed() {
  if (duration < 0 || power < 0) {
    if (key == '\n' ) {
      if (duration < 0) {
        duration = Float.parseFloat(typing); 
        savedDur = typing;
      }
      else {
        power = Integer.parseInt(typing); 
        savedPow = typing;
      }
      typing = ""; 
    } else {
      if (!Character.isDigit(key)){
      return;
    }
      // Otherwise, concatenate the String
      // Each character typed by the user is added to the end of the String variable.
      typing = typing + key; 
      if (duration < 0) {
        savedDur = typing; 
      }
      else {
        savedPow = typing;
      }
    }
  }
}

void setup() {
  size(900, 650, P3D);
  path = sketchPath(audioName);
  file = new SoundFile(this, path);
  file.loop();
  wellDone = 0;
  ortho(-width/2, width/2, -height/2, height/2);
  hs1 = new HScrollbar(270, height/2-30, width/4, 16, 16);
  hs2 = new HScrollbar(270, height/2+30, width/4, 16, 16);
  myPort = new Serial (this, Serial.list()[0], 9600);
    // Load images
    bubbleimage = loadImage("image.jpeg");
    
    // Initialize the two-dimensional tile array
    for (int i=0; i < columns; i++) {
        for (int j=0; j<rows; j++) {
            // Define a tile type and a shift parameter for animation
            tiles[i][j] = new Tile(i, j, 0, 0);
        }
    }
    width1 = columns * tilewidth + tilewidth/2;
    height1 = (rows-1) * rowheight + tileheight;
    
    // Init the player
    player.x = x + width1/2 - tilewidth/2 + 70;
    player.y = y + height1;
    player.angle = 90;
    player.tiletype = 0;
    player.nextbubble.x = player.x - 2 * tilewidth;
    player.nextbubble.y = player.y;

    newGame();
}

void mousePressed(){
  if (!settings) {
    float x1 = width - tilewidth*2.5;
    float y1 = tilewidth * 3;
    if ((mouseX - x1)*(mouseX - x1) + (mouseY-y1)*(mouseY-y1) <= tilewidth*tilewidth*0.75*0.75) {
      settings = true;
      instructions = false;
    }
  }
  if (!instructions) {
    float x1 = width - tilewidth*2.5;
    float y1 = tilewidth * 5;
    if ((mouseX - x1)*(mouseX - x1) + (mouseY-y1)*(mouseY-y1) <= tilewidth*tilewidth*0.75*0.75) {
      instructions = true;
      settings = false;
    }
  }
  if (settings) {
    float x1 = 350 + tilewidth;
    float y1 = 500;
    if ((mouseX - x1)*(mouseX - x1) + (mouseY-y1)*(mouseY-y1) <= tilewidth*tilewidth){
      settings = false;
    }
  }
  else if (instructions) {
    float x1 = 350 + tilewidth;
    float y1 = 500;
    if ((mouseX - x1)*(mouseX - x1) + (mouseY-y1)*(mouseY-y1) <= tilewidth*tilewidth){
      instructions = false;
    }
  }
}


void draw() {
  drawCenterText("Bubbles Game");
  noStroke();
  lights();
  background(204,229,255);
  if (gamestate == win) {
    textSize(100);
    text("You Won!", width/2 - 200, height/2);
    fill(0);
    return;
  }
  if (gamestate == gameover) {
    textSize(100);
    text("Game Over", width/2 - 200, height/2);
    fill(0);
    return;
  }
  if (wellDone > 0){   
    textSize(20);
    text("Well Done!", width - 150, height - 200);
    fill(0);
    wellDone--;
  }
  drawSettingsBubbles();
  if (settings) {
    settingsScreen();
    file.loop();
  }
  else if (instructions) {
    instructionsScreen();
    file.stop();
  }
  else {
    update();
    render();
    if (pressureCheck2()) {
      breath();
    }
  }
}
