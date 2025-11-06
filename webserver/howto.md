# Dana WASM runtime

This package contains a Dana runtime compiled to WASM, which will run in any modern web browser.

This package also contains the entire Dana standard library compiled in a suitable target format for the runtime.

## General restrictions

The main, general restriction of working in WASM is that the `App:main()` method of your system cannot block; it must exit in order for the browser-resident system to remain responsive. Because most programs need to run continuously, Dana allows you to register a `lang.ProcessLoop` object with its runtime. If you do this, after the `main` method exits, the `loop()` function of your `ProcessLoop` object will be called. Your implementation of `loop()` should do some work, then return `true` if it wishes to be called again, or `false` if the program has ended. The `loop()` function also *cannot block*, so your system must be designed perform its tasks across many iterations of the `loop()` function. The slower the `loop()` function is in doing its work, the less responsive the browser may appear to be.

## Networking

`net.TCP`, `net.SSL`, `net.UDP`, `net.DNS`

WASM does not support low-level socket operations, so none of the above APIs are included, nor are any components which depend upon them such as `net.smtp.SMTP`.

Instead, you may use only `net.http.HTTPRequest` for any remote operations. Note that the `HTTPRequest` functions cannot be used from the main thread (including from the `ProcessLoop:loop()` function). This is a WASM restriction. In the web server that you choose to host your WASM application you'll also need to take care of any CORS requirements when using HTTP requests from within a web browser. For more on this see: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS

## User Interfaces

The full standard UI package is supported, with the exception that the `App:main()` method must return for the system to be responsive, as explained above (it cannot sit in an indefinite render- or event-loop).

The desktop app UI framework can be used almost exactly as it is in a non-WASM environment, except that the `IOLayer.run()` method cannot be used (because it would block the `main` method). Instead, you need to use the `System.setProcessLoop()` API to delegate the UI event loop to the WASM runtime, passing in your `IOLayer` instance as a parameter.

The videogame UI framework must similarly delegate its render/event loop using `System.setProcessLoop(x)`, but in this case you'll need to write your own interface which inherits from `lang.ProcessLoop`, the implementation of which has all of your render and event logic within the `loop()` function. We provide examples lower down in this document of simple UI applications in both of these styles.

## Audio

An `io.audio.AudioOut` device **must** be instantiated from inside your `ProcessLoop` implementation's `loop()` function, and must be instantiated only following a qualifying user interaction with the application (typically a mouse click). After instantiation, you must then poll the audio output device once-per-loop with the `ready()` function until `ready()` returns `true`.

## Injecting your code

The runtime that we distribute (dana.wasm) contains the Dana runtime plus its native libraries (with the above exceptions). To make it do something, you need to include your own program (i.e., an implementation of `App`) and include whichever parts of the Dana standard library that your system relies on. This requires the following steps.

### 1. Compile your code for UBC/32

First, compile your own code for a WASM output target. To do this, use the command:

`dnc MyThing.dn -os ubc -chip 32 -o App.o`

The entry point of your system *must* be in a file called `App.o`. You can have as many other components as you like that form part of your system, in whatever packages you like.

### 2. Package your code

Our runtime assumes that a JavaScript file exists called `file_system.js`. This JS file is where all of the files are embedded which will be downloaded alongside the Dana runtime. This includes compiled components, plus any dependent files. To create a `file_system.js` file you'll need the Emscripten SDK (emsdk) installed on your computer. You can see instructions for this here: https://emscripten.org/docs/getting_started/downloads.html

The emsdk package includes a tool called `file_packager`, which is a Python script. This tool is able to create your JS file which embeds all of the filesystem entries. The tool is often in the `upstream/emscripten/tools/` sub-directory of emsdk, and you may need to use the full path, but in the below examples we're just using the tool name directly.

If you have a simple "hello world" application, comprised of a single App component which uses only the `io.Output` required interface, you can build your filesystem as:

`file_packager dana.wasm --embed MyCompiledThing.o@App.o --js-output=file_system.js`

To include the entire Dana standard library, you can do:

`file_packager dana.wasm --embed MyCompiledThing.o@App.o --embed components/@components --js-output=file_system.js`

The Dana standard library must be in a directory called `components` in the root of the file system.

You can also select just the components you want from the standard library, and place them in the correct sub-directories of `components` depending on their package structure.

## Running your system

You'll now need a web server to host your system, and a web browser to view it. You'll need to place the files `xdana.html`, `dana.js`, `file_system.js`, and `dana.wasm`, all in the same place on your web server.

You can then point your web browser at the `xdana.html` file, and you should see your system running. You can rename the `xdana.html` file to anything you like, and can also edit the HTML to embed it in whatever page style you like.

## Examples

### Example app UI

Here we're going to show a full example of a user interface application running in WASM, from writing the code to packaging it. We'll use the built-in web server from Dana's standard library to host the system, so you won't need anything else installed besides Dana itself.

We'll assume that you have Dana installed on your computer (i.e., if you're running Windows on a 64-bit Intel computer, you have the win-x86-64 version of Dana installed).

We assume that you've downloaded the Dana WebAssembly package and extracted it somewhere. We're going to assume that the commands we execute below are from a terminal in the directory to which you extracted those files. We also assume that you have the emsdk installed, specifically with access to the `file_packager` tool.

Let's create a simple Dana app, which looks like this:

```
component provides App requires io.Output out, ui.IOLayer, ui.Window, ui.Button, ui.Label, System system {

	IOLayer coreui
	Window window
	Button b1
	Button b2
	Label label

	eventsink AppEvents(EventData ed)
		{
		if (ed.type == Button.[click] && ed.source === b1)
			{
			label.setText("Button one clicked")
			}
			else if (ed.type == Button.[click] && ed.source === b2)
			{
			label.setText("Button two clicked")
			}
		}

	eventsink SysEvents(EventData ed)
		{
		if (ed.source === coreui && ed.type == IOLayer.[ready])
			{
			startApp()
			}
			else if (ed.source === window && ed.type == Window.[close])
			{
			window.close()
			coreui.shutdown()
			}
		}

	void startApp()
		{
		window = new Window("My Web Window")
		window.setSize(250, 100)
		window.setVisible(true)
		
		b1 = new Button("One")
		b2 = new Button("Two")
		label = new Label("")
		
		b1.setPosition(10, 30)
		b2.setPosition(70, 30)
		label.setPosition(10, 60)
		
		window.addObject(b1)
		window.addObject(b2)
		window.addObject(label)
		
		sinkevent AppEvents(b1)
		sinkevent AppEvents(b2)
		
		sinkevent SysEvents(window)
		}
	
	int App:main(AppParam params[])
		{
		//initialise the system-level UI framework
		coreui = new IOLayer()
		
		//listen for startup events from the system
		sinkevent SysEvents(coreui)
		
		//run UI system loop, delegated as a process loop
		system.setProcessLoop(coreui)
		
		return 0
		}

}
```

We'll save this as `App.dn` in the directory you've extracted Dana WebAssembly into. It doesn't have to be in this directory, but it makes our instructions here simpler. We then compile this file as:

`dnc App.dn -os ubc -chip 32`

Now we create a file system image which contains this application, plus the Dana standard library:

`file_packager dana.wasm --embed App.o@App.o --embed components/@components --js-output=file_system.js`

Including the entire standard library for this simple example application is rather wasteful in file size, but again it simplifies these instructions.

You can't run WASM files by opening them in a browser directly, so we now need to start up a web server. We'll use the `ws.core` webserver which is packaged with Dana. This webserver assumes it's going to run a web application, so we've provided a simple default one which you need to compile for your native host with the command:

`dnc ws`

Finally, you can type:

`dana ws.core`

And open a web browser, pointing it at http://localhost:8080/xdana.html

### Example game UI

We'll assume here that you've followed all of the "setup" instructions above, for setting up the `ws.core` web server. You can leave this web server running as you try out different examples, since we'll be re-generating the `file_system.js` file each time, which contains your program and any dependent code. You might need to do a hard page refresh in your browser, though, to skip any caching effects on files.

In this example we use a game-like main loop for our user interface, giving more direct control over rendering. To do this we need an implementation of `App` for our `main()` method, and an implementation an an interface that inherits from `lang.ProcessLoop` (because our main method cannot itself set in a rendering loop as this would make the web browser unresponsive).

Our simple `App` implementation, in a file `App.dn`, will look like this:

```
component provides App requires io.Output out, System system, RenderApp {
	
	int App:main(AppParam params[])
		{
		system.setProcessLoop(new RenderApp())
		
		return 0
		}
}
```

Next we need a new type definition for `RenderApp`. Create a directory called `resources`, and inside that directory create a file called `RenderApp.dn` with the contents:

```
interface RenderApp extends lang.ProcessLoop {
	RenderApp()
	}
```

And finally we create our implementation of `RenderApp`. Back in the root directory, where `App.dn` is, create a new file called `RenderApp.dn` with the contents:

```
component provides RenderApp requires ui.FlowRender, ui.FlowCanvas, ui.FlowFont, time.Timer timer {
	FlowRender window
	FlowCanvas canvas
	
	RenderApp:RenderApp()
		{
		window = new FlowRender(60)
		window.setSize(400, 200)
		canvas = new FlowCanvas(window)

		window.setTitle("Direct Render Loop")
		window.setVisible(true)
		}
	
	bool processEvents(FlowEvent events[])
		{
		bool quit = false
		for (int i = 0; i < events.arrayLength; i++)
			{
			if (events[i].type == FlowEvent.T_QUIT)
				{
				quit = true
				}
			}
		
		return quit
		}
	
	Ellipse2D ball = new Ellipse2D(10, 100, 80, 80, new Color(100, 100, 200, 255))
	int x = 100
	bool right = true
	
	bool RenderApp:loop()
		{
		bool quit = false

		FlowEvent events[] = window.getEvents()

		window.renderBegin()
		ball.x = x
		canvas.ellipse(ball)	
		window.renderEnd()

		quit = processEvents(events)

		if (right)
			{
			x += 2
			if (x > 300) right = false
			}
			else
			{
			x -= 2
			if (x == 80) right = true
			}
		
		timer.sleep(5)

		return !quit
		}
}
```

We can now compile our project for WebAssembly with:

`dnc App.dn -os ubc -chip 32`

`dnc RenderApp.dn -os ubc -chip 32`

And package our files with:

`file_packager dana.wasm --embed App.o@App.o --embed RenderApp.o@RenderApp.o --embed components/@components --js-output=file_system.js`

Assuming that `ws.core` is still running, you can just refresh the browser page to see the new system running, at http://localhost:8080/xdana.html
