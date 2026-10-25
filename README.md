# Using Gemini LLM in Godot

This project was built using the Godot Engine and explores how to integrate Gemini LLM features into a small game-like project that mixes in-game systems with AI tools.

## How to run it

You can run it in two ways:

- Clone this repository and open the project folder in the Godot editor.
- Download the executable version once it is available (.exe will be added soon).

The project was created with Godot 4.7, so that version is recommended for the best compatibility.

## How it works

The application allows the user to enter their own Gemini API key directly inside the app, without relying on any external files or additional programs to run it. The project is designed to be self-contained and simple to use, and it now supports model selection.

Users can:

- enter their Gemini API key from inside the application,
- load the list of models available for that specific API key,
- view which Gemini models are compatible with the current API,
- select any specific Gemini model before sending a request.

This makes it easier to test different Gemini models and switch between compatible options without leaving the app or editing configuration files.

## Notes

- Preferably open the project in Godot 4.7, since that is the version used to create it.
- If you use the executable build, you can add your own API key in the application itself.
- The app can display the models available to your API and let you pick the one you want to use.
- This keeps the workflow simple and does not require any extra setup beyond the engine or the generated executable.
