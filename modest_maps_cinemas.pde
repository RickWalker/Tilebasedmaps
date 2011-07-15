
//Rick Walker 1/2010
//uses the Modest Maps Processing example and overlays
//cinema location data (as provided by Amy Chambers) onto it.
//then uses the SPH weighted averaging technique to colour areas 
//on the map appropriately.

// this is the only bit that's needed to show a map:
InteractiveMap map;

// buttons take x,y and width,height:
ZoomButton out = new ZoomButton(5,5,14,14,false);
ZoomButton in = new ZoomButton(22,5,14,14,true);
PanButton up = new PanButton(14,25,14,14,UP);
PanButton down = new PanButton(14,57,14,14,DOWN);
PanButton left = new PanButton(5,41,14,14,LEFT);
PanButton right = new PanButton(22,41,14,14,RIGHT);

Location [] cinemaLocations;
boolean updateNeeded;
float [] xpos; 
float [] ypos; 
String [] cinemaNames;
int closest;
float [] [] overlay; //the values to overlay per pixel
float max_intensity;

// all the buttons in one place, for looping:
Button[] buttons = { 
  in, out, up, down, left, right };

PFont font;

boolean gui = true;

void setup() {
  size(600, 600);

  overlay = new float[width][height];
  smooth();
  frameRate(15);
  loadData();
  updateNeeded = true;

  // create a new map, optionally specify a provider
  map = new InteractiveMap(this, new Microsoft.AerialProvider());
  // others would be "new Microsoft.HybridProvider()" or "new Microsoft.AerialProvider()"
  // the Google ones get blocked after a few hundred tiles
  // the Yahoo ones look terrible because they're not 256px squares :)

  // set the initial location and zoom level to Bangor:
  map.setCenterZoom(new Location(53.228267, -4.127942), 8);
  //map.setCenterZoom(new Location(53.194, -3.406), 14);
  // zoom 0 is the whole world, 19 is street level
  // (try some out, or use getlatlon.com to search for more)

  // set a default font for labels
  font = createFont("Helvetica", 12);

  // enable the mouse wheel, for zooming
  addMouseWheelListener(new java.awt.event.MouseWheelListener() { 
    public void mouseWheelMoved(java.awt.event.MouseWheelEvent evt) { 
      mouseWheel(evt.getWheelRotation());
    }
  }
  ); 

}

void loadData(){
  String [] lines = loadStrings("cinemalist.txt");
  int cinema_count = lines.length/3;
  println("Found "+cinema_count+ " cinemas");
  cinemaLocations = new Location[cinema_count];
  xpos = new float[cinemaLocations.length];
  ypos = new float[cinemaLocations.length];
  cinemaNames = new String[cinema_count--];
  for(int i = 0;i<lines.length;i+=3){
    //parse line into two tokens
    cinemaNames[cinema_count] = lines[i];
    String [] latlon = splitTokens(lines[i+2],",");
    cinemaLocations[cinema_count--]=new Location(float(latlon[0]), float(latlon[1]));
  }
}

void draw() {
  //if(updateNeeded){
  background(0);

  // draw the map:
  map.draw();
  // (that's it! really... everything else is interactions now)

  smooth();

  // draw all the buttons and check for mouse-over
  boolean hand = false;
  if (gui) {
    for (int i = 0; i < buttons.length; i++) {
      buttons[i].draw();
      hand = hand || buttons[i].mouseOver();
    }
  }

  // if we're over a button, use the finger pointer
  // otherwise use the cross
  // (I wish Java had the open/closed hand for "move" cursors)
  cursor(hand ? HAND : CROSS);

  // see if the arrow keys or +/- keys are pressed:
  // (also check space and z, to reset or round zoom levels)
  if (keyPressed) {
    if (key == CODED) {
      if (keyCode == LEFT) {
        map.tx += 5.0/map.sc;
      }
      else if (keyCode == RIGHT) {
        map.tx -= 5.0/map.sc;
      }
      else if (keyCode == UP) {
        map.ty += 5.0/map.sc;
      }
      else if (keyCode == DOWN) {
        map.ty -= 5.0/map.sc;
      }
    }  
    else if (key == '+' || key == '=') {
      map.sc *= 1.05;
    }
    else if (key == '_' || key == '-' && map.sc > 2) {
      map.sc *= 1.0/1.05;
    }
  }

  if (gui) {
    textFont(font, 12);

    // grab the lat/lon location under the mouse point:
    Location location = map.pointLocation(mouseX, mouseY);

    // draw the mouse location, bottom left:
    fill(0);
    noStroke();
    rect(5, height-5-g.textSize, textWidth("mouse: " + location), g.textSize+textDescent());
    fill(255,255,0);
    textAlign(LEFT, BOTTOM);
    text("mouse: " + location, 5, height-5);

    // grab the center
    location = map.pointLocation(width/2, height/2);

    // draw the center location, bottom right:
    fill(0);
    noStroke();
    float rw = textWidth("map: " + location);
    rect(width-5-rw, height-5-g.textSize, rw, g.textSize+textDescent());
    fill(255,255,0);
    textAlign(RIGHT, BOTTOM);
    text("map: " + location, width-5, height-5);
    createSurface();
    //println(max_intensity);
    colorMode(HSB, 50);
    for(int x = 0; x < width; x++){
      for(int y = 0; y < height; y++){
        //fill( map(overlay[x][y], 0, max_intensity, 0, 255), 0, 0, map(overlay[x][y], 0, max_intensity, 0, 255));
        //noStroke();
        if(overlay[x][y] != 0.0){
          stroke(map(overlay[x][y], 0, max_intensity, 37, 2), 50, 50, map(overlay[x][y], 0, max_intensity, 2, 40));
          //ellipse(x,y,10,10);
          point(x, y); 
        }
      }
    }
    colorMode(RGB, 255);
    ellipseMode(CENTER);
    for(int i = 0 ; i < cinemaLocations.length ; i++){
      Point2f p = map.locationPoint(cinemaLocations[i]);
      fill(255, 255, 255);
      ellipse(p.x, p.y, 10, 10);
    }

    checkForMouseOver();


    //this is exactly the same as SPH calculation - 
    //apply the same optimisation stuff that SPLASH uses and I used in my C++ code
    //so: work per location instead of pixel!
    //still need big loop to draw I guess?
    updateNeeded = false;
    //}
  }  

  //println((float)map.sc);
  // println((float)map.tx + " " + (float)map.ty);
  //println();

}

void createSurface(){
  //clear old surface
  for(int i = 0 ; i < width; i++){
    for(int j = 0 ; j < height; j++){
      overlay[i][j] = 0.0;
    }
  }

  //NEW PLAN:

  //measure all distances in Miles
  //work out ipixmin/max etc using proper formulae
  //How about this: new array of locations that're relative to top left corner and scaled by extent
  Location zerozero = map.pointLocation(0, 0);
  Location widthheight = map.pointLocation(width, height);
  float boxsize_x, boxsize_y;
  boxsize_x = distanceBetween(zerozero, new Location(widthheight.lat, zerozero.lon));
  boxsize_y = distanceBetween(zerozero, new Location(zerozero.lat, widthheight.lon));

  //println("box is " + zerozero.lat + ", " + zerozero.lon + " and " + widthheight.lat + ", " + widthheight.lon);
  //println("Box size in miles is " + boxsize_x + " by " + boxsize_y);
  for(int i = 0; i < cinemaLocations.length; i++){
    ypos[i] = distanceBetween(zerozero, new Location(cinemaLocations[i].lat, zerozero.lon));
    if(cinemaLocations[i].lat > zerozero.lat)
      ypos[i] *= -1;

    //println("Calculating distance between " + zerozero.toString() + " and " + new Location(zerozero.lat, cinemaLocations[i].lon).toString());
    xpos[i] = distanceBetween(zerozero, new Location(zerozero.lat, cinemaLocations[i].lon)); //need signed distance!
    if(cinemaLocations[i].lon < zerozero.lon)
      xpos[i] *= -1;

    //if(ypos[i]>0 && xpos[i]>0 && xpos[i]<=boxsize_x && ypos[i] <= boxsize_y){
    //println("Cinema " + cinemaNames[i] + " " + i + " is visible with "+ xpos[i] + ", " + ypos[i]);
    //println("Original lat lon " + cinemaLocations[i].lat + ", " + cinemaLocations[i].lon);
    // }
    //println("Zero zero is " + zerozero.lat +", " + zerozero.lon);
    //println("cinema is " + cinemaLocations[i].lat + ", " + cinemaLocations[i].lon);
    //println("Distance to " + i + " is " + xpos[i] + " " + ypos[i]);
  }
  //println();




  max_intensity = Float.MIN_VALUE;
  //creates the surface
  double cinema_density = 100000.0;
  double cinema_mass=100.0;
  double r_cloud = distanceBetween(zerozero, new Location(zerozero.lat, map.pointLocation(width, 0).lon)); //convert to miles!
  //println("Zero zero is " + zerozero.lat +", " + zerozero.lon);
  //println("Height is " + height);
  //println("Other point is " + zerozero.lat + ", " + map.pointLocation(width, 0).lon);
  //println("r_cloud is " + r_cloud);
  double h = 5.0;// r_cloud / 20.0; //smoothing length
  double twoh = 2 * h;//2*smoothing length (kernel radius)
  double hi1 = 1.0/h; // 1/hi
  double hi21 = hi1 * hi1; //1/h^2
  int npixx = width - 1;
  int npixy = height - 1;
  double xmin = 0;//map.pointLocation(0, 0).lat;
  double ymin = 0;//map.pointLocation(0, 0).lon;
  //  double pixwidth = (2.0 * r_cloud) / npixx; //can't do it like this!
  //it needs to be the distance between subsequent pixels
  double pixwidth = r_cloud / (float) width;
  //println(pixwidth);
  //double pixwidth_i = distanceBetween(map.pointLocation(0, 0), map.pointLocation(1, 0));
  double ypix;
  int ipix, jpix, ipixmin, ipixmax, jpixmin, jpixmax;
  double dy, dy2;
  double [] dx2i=new double[npixx+1];
  double qq,qq2,wab;
  double w_j;
  double termnorm, term;

  for(int i = 0 ; i < cinemaLocations.length ; i++){
    //ipixmin is the minimum x value that this cinema affects
    //so need to find the coordinates of the point twoh miles west of it, then take xmin from that?

    //ipixmin = (int) ((cinemaLocations[i].lat - twoh - xmin) / pixwidth_i);
    ipixmin = (int) ((xpos[i] - twoh) / pixwidth);
    jpixmin = (int) ((ypos[i] - twoh) / pixwidth);
    ipixmax = (int) ((xpos[i] + twoh) / pixwidth) + 1;
    jpixmax = (int) ((ypos[i] + twoh) / pixwidth) + 1;

    if (ipixmin<0) ipixmin = 0;
    if (jpixmin<0) jpixmin = 0;
    if (ipixmax>npixx) ipixmax = npixx;
    if (jpixmax>npixy) jpixmax = npixy;

    for(ipix=ipixmin;ipix<=ipixmax;ipix++){
      dx2i[ipix]=(((ipix-0.5)*pixwidth - xpos[i]) * ( (ipix-0.5) * pixwidth - xpos[i]))*hi21; // + dz2;
    }

    //assume total'mass' 100 and each 'density' is 50
    //eventually, mass = , density = showings per day per screen
    w_j = (cinema_mass / cinemaLocations.length)/(cinema_density * hi1 * hi21);
    termnorm = 10./(7.*PI)*w_j;
    term = termnorm* cinema_density;
    //println(term);
    //println("jpixmin " + jpixmin + " jpixmax " + jpixmax);
    for (jpix=jpixmin;jpix<=jpixmax;jpix++){
      ypix=ymin+(jpix-0.5)*pixwidth;
      dy=ypix-ypos[i];
      dy2=dy*dy*hi21;
      //println("In jpix loop!");
      for(ipix=ipixmin;ipix<=ipixmax;ipix++){
        qq2=dx2i[ipix] + dy2;
        //println(qq2);
        //SPH Cubic spline
        //if in range
        if(qq2<4.0){
          qq=Math.sqrt(qq2);
          if(qq<1.0){
            wab=(1.-1.5*qq2 + 0.75*qq*qq2);
          }
          else{ 
            wab=0.25*(2.-qq)*(2.-qq)*(2.-qq);
          }						
          overlay[ipix][jpix]+= term*wab;
          //println("Adding " + term*wab);
          max_intensity = max(overlay[ipix][jpix], max_intensity);
        }
      }
    }
  }

}


float distanceBetween(Location l1, Location l2){
  //proper haversine formula!
  float lat1 = radians(l1.lat);
  float lat2 = radians(l2.lat);
  float lon1 = radians(l1.lon);
  float lon2 = radians(l2.lon);
  //r is radius of earth
  int r = 3959;
  float dlat = lat2 - lat1;
  float dlon = lon2 - lon1;
  //float a = (sin(dlat/2.0))^2 + cos(l1.lat) * cos(l2.lat) * (sin(dlon/2.0))^2;
   float a = (sin(dlat/2.0)*sin(dlat/2.0)) + cos(lat1) * cos(lat2) * (sin(dlon/2.0))* (sin(dlon/2.0));
  float c = 2 * atan2(sqrt(a), sqrt(1-a)) ;
  float  d = r * c;
  return d;

  //return acos(cos(radians(a.lat)) * cos(radians(b.lat)) * cos(radians(b.lon - a.lon)) + sin(radians(a.lat)) * sin(radians(b.lat))) * r;
}

void keyReleased() {
  if (key == 'g' || key == 'G') {
    gui = !gui;
  }
  else if (key == 's' || key == 'S') {
    save("modest-maps-app.png");
  }
  else if (key == 'z' || key == 'Z') {
    map.sc = pow(2, map.getZoom());
  }
  else if (key == ' ') {
    map.sc = 2.0;
    map.tx = -128;
    map.ty = -128; 
  }
}

void mouseMoved(){
  //check for mouseover events
  //convert each location to pixel position
  //find the one closest to the mouse
  // print it
  closest = -1;
  for (int i = 0 ; i < cinemaLocations.length; i++){
    Point2f actual = map.locationPoint(cinemaLocations[i]);
    if( abs( actual.x - mouseX ) < 5){
      if( abs(actual.y - mouseY ) < 5){
        closest = i;
        updateNeeded = true;
      }
    }
  }
}

void checkForMouseOver(){

  if (closest != -1){
    //println("Closest to..." + closest);
    //label time!
    stroke(0, 0, 0);
    fill(255, 255, 255);
    textAlign(LEFT, BOTTOM);
    text(cinemaNames[closest], mouseX, mouseY - 5);
  }
}


// see if we're over any buttons, otherwise tell the map to drag
void mouseDragged() {
  updateNeeded = true;
  boolean hand = false;
  if (gui) {
    for (int i = 0; i < buttons.length; i++) {
      hand = hand || buttons[i].mouseOver();
      if (hand) break;
    }
  }
  if (!hand) {
    map.mouseDragged(); 
  }
}

// zoom in or out:
void mouseWheel(int delta) {
  updateNeeded = true;
  if (delta > 0) {
    map.sc *= 1.05;
  }
  else if (delta < 0) {
    map.sc *= 1.0/1.05; 
  }
}

// see if we're over any buttons, and respond accordingly:
void mouseClicked() {
  updateNeeded = true;
  if (in.mouseOver()) {
    map.zoomIn();
  }
  else if (out.mouseOver()) {
    map.zoomOut();
  }
  else if (up.mouseOver()) {
    map.panUp();
  }
  else if (down.mouseOver()) {
    map.panDown();
  }
  else if (left.mouseOver()) {
    map.panLeft();
  }
  else if (right.mouseOver()) {
    map.panRight();
  }
}






























