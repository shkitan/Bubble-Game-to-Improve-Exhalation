# Bubble-game-to-improve-exhalation
Developing a version of the Bubbles game aimed at promoting deep breathing techniques for children coping with illness.

"Blow Up the Bubbles by Breath" is a soothing game crafted to foster deep breathing among ill children. By blowing bubbles and concentrating on their gentle movements, children partake in tranquil breathing exercises that foster relaxation and overall well-being. This innovative method seamlessly blends amusement with therapeutic benefits to aid children throughout their healing journey.

We connected an Arduino to the computer, which detects the joystick sensor 
and moves the game arrow accordingly. When a sufficient level of breath 
intensity is detected, a 'send' action is performed, sending the bubble to the 
board.

I add a video in which we can see how I play this game

Files explanation:
1. bubbles_arduino.ino - code for the arduino. we have two sensors:
    - joystick which control the arrow direction
    - atmospheric pressure - detects the breath intensity
2. bubbles.pde - code for the game (both vision and algorithmic code)
3. music.mp3 - background music game
4. Shkitan Playing & Screenshot.mp4: demonstration