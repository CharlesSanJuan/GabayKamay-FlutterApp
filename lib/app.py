#THIS PART IS PARA SA BACKEND NG FLASK APP NA GUMAGAMIT NG GOOGLE TEXT-TO-SPEECH (gTTS) LIBRARY PARA 
# I-CONVERT ANG TEKSTO SA AUDIO FILE NA "speech.mp3". ANG FLASK APP AY MAY DALAWANG ROUTES: 
# ISANG POST ROUTE PARA TUMANGGAP NG TEKSTO AT ISANG GET ROUTE PARA IBIGAY ANG AUDIO FILE SA CLIENT.


from flask import Flask, request, send_file
from flask_cors import CORS
from gtts import gTTS

app = Flask(__name__)
CORS(app)

@app.route('/speak', methods=['POST'])
def speak():
    data = request.json
    text = data.get("text", "")

    tts = gTTS(text=text, lang='en')
    tts.save("speech.mp3")

    return {"status": "ok"}

@app.route('/speech.mp3')
def speech():
    return send_file("speech.mp3", mimetype="audio/mpeg")

if __name__ == "__main__":
    app.run(port=5000)