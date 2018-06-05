package ;

import zui.*;
import zui.Zui;
import zui.Canvas;


@:access(zui.Zui)

class Elements {
	var ui:Zui;
	var cui:Zui;
	var canvas:TCanvas;

	static var uiw(get, null):Int;
	static function get_uiw():Int {
		return Std.int(240 * Main.prefs.scaleFactor);
	}
	static var coff = 40;

	var dropPath = "";
	var drag = false;
	var dragLeft = false;
	var dragTop = false;
	var dragRight = false;
	var dragBottom = false;
	var assetNames:Array<String> = [];
	var dragAsset:TAsset = null;
	var comboCounter = 0;
	var maxComboSize = 25;
	var defaultSliderRange = 1000.0;//Will be positive value(to) and negative value(from)
	var sliderCounter = 0;
	var maxGroupSize = 15;
	var elementAddGroup:TElement;
	var buttonNames = ['Text', 'Image','Button', 'Check','Radio', 'Combo', 'Slider','ButtonGroup','CheckGroup','RadioGroup'];
	var elementNavGroup:TElement;
	var navButnNames = ['Up','Down', 'Remove'];

	public function new(canvas:TCanvas) {
		this.canvas = canvas;

		initializeButtonGroups();
		// Reimport assets
		if (canvas.assets.length > 0) {
			var assets = canvas.assets;
			canvas.assets = [];
			for (a in assets) importAsset(a.file);
		}

		// var _onDrop = onDrop;
		// untyped __js__("
		// document.ondragover = document.ondrop = (ev) => {
		// 	ev.preventDefault()
		// }
		// document.body.ondrop = (ev) => {
		// 	_onDrop(ev.dataTransfer.files[0].path);
		// 	ev.preventDefault()
		// }
		// ");

		kha.Assets.loadEverything(loaded);
	}

	static function toRelative(path:String, cwd:String):String {
        path = haxe.io.Path.normalize(path);
        cwd = haxe.io.Path.normalize(cwd);
        
        var ar:Array<String> = [];
        var ar1 = path.split("/");
        var ar2 = cwd.split("/");
        
        var index = 0;
        while (ar1[index] == ar2[index]) index++;
        
        for (i in 0...ar2.length - index) ar.push("..");
        
        for (i in index...ar1.length) ar.push(ar1[i]);
        
        return ar.join("/");
    }

    static function toAbsolute(path:String, cwd:String):String {
        return haxe.io.Path.normalize(cwd + "/" + path);
    }

	function loaded() {
		var t = Reflect.copy(Themes.dark);
		t.FILL_WINDOW_BG = true;
		ui = new Zui({scaleFactor: Main.prefs.scaleFactor, font: kha.Assets.fonts.DroidSans, theme: t, color_wheel: kha.Assets.images.color_wheel});
		cui = new Zui({scaleFactor: 1.0, font: kha.Assets.fonts.DroidSans, autoNotifyInput: false});

		kha.System.notifyOnDropFiles(function(path:String) {
			dropPath = StringTools.rtrim(path);
			dropPath = toRelative(dropPath, Main.cwd);
		});

		kha.System.notifyOnRender(render);
		kha.Scheduler.addTimeTask(update, 0, 1 / 60);
	}

	function importAsset(path:String) {
		if (!StringTools.endsWith(path, ".jpg") &&
			!StringTools.endsWith(path, ".png") &&
			!StringTools.endsWith(path, ".k") &&
			!StringTools.endsWith(path, ".hdr")) return;
		
		var abspath = toAbsolute(path, Main.cwd);
		abspath = kha.System.systemId == "Windows" ? StringTools.replace(abspath, "/", "\\") : abspath;

		kha.Assets.loadImageFromPath(abspath, false, function(image:kha.Image) {
			var ar = path.split("/");
			var name = ar[ar.length - 1];
			var asset:TAsset = { name: name, file: path, id: Canvas.getAssetId(canvas) };
			canvas.assets.push(asset);
			Canvas.assetMap.set(asset.id, image);

			assetNames.push(name);
			hwin.redraws = 2;
		});
	}

	function initializeButtonGroups(){
		
		//Buttons for Adding elements
		var onAddEvent = function (str: String){
			var elem = makeElem(ElementType.getType(str));
			canvas.elements.push(elem);
			hradio.position = canvas.elements.length - 1;
		}
		elementAddGroup= makeElem(ElementType.ButtonGroup);
		elementAddGroup.name = 'TREE';
		elementAddGroup.modifiers.set('elements', []);
		elementAddGroup.modifiers.set('elementType', 'Button');
		var i = buttonNames.length;
		while(i-- > 0){
			var elem = makeElem(ElementType.Button);
			elem.text = buttonNames[i];
			elem.modifiers.set('callback', onAddEvent);
			elementAddGroup.modifiers['elements'].push(elem);
		}

		// Buttons for Nav and remove of elements
		var onNavEvent = function (str: String){
			var t = canvas.elements[selectedElem];
			if(str == 'Up' && selectedElem < canvas.elements.length-1){
				canvas.elements[selectedElem] = canvas.elements[selectedElem + 1];
				canvas.elements[selectedElem + 1] = t;
				selectedElem++;
			}
			else if(str == 'Down' && selectedElem > 0){
				canvas.elements[selectedElem] = canvas.elements[selectedElem - 1];
				canvas.elements[selectedElem - 1] = t;
				selectedElem--;
			}
			else if(str == 'Remove' && canvas.elements.length > 0){
				removeSelectedElem();
			}
			hradio.position = selectedElem;
		}
		elementNavGroup= makeElem(ElementType.ButtonGroup);
		elementNavGroup.name = 'TREE';
		elementNavGroup.modifiers.set('elements', []);
		elementNavGroup.modifiers.set('elementType', 'Button');
		i = navButnNames.length;
		while(i-- > 0){
			var elem = makeElem(ElementType.Button);
			elem.text = navButnNames[i];
			elem.modifiers.set('callback', onNavEvent);
			elementNavGroup.modifiers['elements'].push(elem);
		}
	}
	function makeElem(type:ElementType) {
		var name = "";
		var height = 100;
		var p_id = Canvas.getElementId(canvas);
		var modifiers:haxe.DynamicAccess<Dynamic> = {};
		if (type == ElementType.Text) {
			name = "Text";
			height = 48;
		}
		else if (type == ElementType.Button) {
			name = "Button";
		}
		else if (type == ElementType.Image) {
			name = "Image";
		}
		else if(type == ElementType.Combo){
			name = "Combo";
			modifiers.set('texts',['None','None']);
			modifiers.set('showLabel', false);
			p_id += comboCounter *maxComboSize;
			comboCounter+=1;
		}
		else if(type == ElementType.Slider){
			name = "Slider";
			modifiers.set('from',0.0);
			modifiers.set('to',1.0);
			modifiers.set('filled', false);
			modifiers.set('displayValue', false);
			modifiers.set('precision', 100);
			p_id += sliderCounter*modifiers.keys().length;
			sliderCounter +=1; 
		}
		else if(type == ElementType.Check){
			name = 'Check';
		}
		else if(type == ElementType.Radio){
			name = 'Radio';
			modifiers.set('currentValue', 0);
		}
		else if(type == ElementType.InlineRadio){
			name = 'InlineRadio';
			modifiers.set('texts',['None','None']);
		}
		else if(type == ElementType.CheckGroup){
			name = 'CheckGroup';
			modifiers.set('elements', [makeElem(ElementType.Check),makeElem(ElementType.Check),makeElem(ElementType.Check)]);
			modifiers.set('elementType', 'Check');
			type = ElementGroup;
		}
		else if(type == ElementType.ButtonGroup){
			name = 'ButtonGroup';
			modifiers.set('elements', [makeElem(ElementType.Button),makeElem(ElementType.Button),makeElem(ElementType.Button)]);
			modifiers.set('elementType', 'Button');
			type = ElementGroup;
		}
		else if(type == ElementType.RadioGroup){
			name = 'RadioGroup';
			modifiers.set('elements', [makeElem(ElementType.Radio),makeElem(ElementType.Radio),makeElem(ElementType.Radio)]);
			modifiers.set('elementType', 'Radio');
			type = ElementGroup;
		}
		var elem:TElement = {
			id: p_id,
			type: type,
			name: name,
			event: "",
			x: 0,
			y: 0,
			width: 150,
			height: height,
			text: name,
			asset: "",
			color: 0xffffffff,
			anchor: 0,
			children: [],
			modifiers: modifiers

		};
		return elem;
	}

	function getEnumTexts():Array<String> {
		return assetNames.length > 0 ? assetNames : [""];
	}

	function getAssetIndex(asset:String):Int {
		for (i in 0...canvas.assets.length) if (asset == canvas.assets[i].name) return i;
		return 0;
	}

	function resize() {
		if (grid != null) {
			grid.unload();
			grid = null;
		}
	}

	static var grid:kha.Image = null;
	function drawGrid() {
		var ww = kha.System.windowWidth(0);
		var wh = kha.System.windowHeight(0);
		var w = ww + 40 * 2;
		var h = wh + 40 * 2;
		grid = kha.Image.createRenderTarget(w, h);
		grid.g2.begin(true, 0xff242424);
		for (i in 0...Std.int(h / 40) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(0, i * 40, w, i * 40);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(0, i * 40 + 20, w, i * 40 + 20);
		}
		for (i in 0...Std.int(w / 40) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(i * 40, 0, i * 40, h);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(i * 40 + 20, 0, i * 40 + 20, h);
		}

		grid.g2.color = 0xffffffff;
		canvas.x = coff;
		canvas.y = coff;
		grid.g2.drawRect(canvas.x, canvas.y, canvas.width, canvas.height, 1.0);

		grid.g2.end();
	}
	function drawModifier(p_id: Int, p_ui: Zui, p_key: String, p_elem: TElement ):Void
	{
		var modifier = p_elem.modifiers.get(p_key);

		if(Std.is(modifier,Array) && Std.is(modifier[0],String)){// Is an Array of strings

			var myarr:Array<String> = modifier;
			var strLen = Math.floor(zui.Zui.clamp(Std.parseInt(p_ui.textInput(Id.handle().nest(p_id, {text: zui.Zui.clamp(myarr.length, 2,maxComboSize) +""} ), "Length", Right)), 2,maxComboSize));

			if( strLen != myarr.length){// Reset combo indexes if needed
				p_elem.modifiers[p_key] = [];
				myarr = [];
				for( y in 0...strLen){
					p_elem.modifiers[p_key].push("None");
				}
			}

			for( i in 0...p_elem.modifiers[p_key].length){ 
				var handle = Id.handle().nest(p_id-i, {text: p_elem.modifiers[p_key][i]} );
				p_elem.modifiers[p_key][i] =p_ui.textInput(handle, "",Right) ;
			}
		}
		else if(Std.is(modifier,Bool)){
			var handle = Id.handle().nest(p_id );
			p_elem.modifiers[p_key] =  p_ui.check(handle, p_key);
		}
		else if(Std.is(modifier,Float) || Std.is(modifier,Int)){
			var handle = Id.handle().nest(p_id, {text: Std.string(modifier)} );
			p_elem.modifiers[p_key] = Std.is(modifier,Int) ? Math.floor(p_ui.slider(handle,p_elem.text,-defaultSliderRange,defaultSliderRange,false,100,true))
			:p_ui.slider(handle,p_elem.text,-defaultSliderRange,defaultSliderRange,false,100,true);
		}
		else if(Std.is(modifier,Array) && p_elem.type == ElementGroup){// Is an Array of Elements

			var myarr = p_elem.modifiers[p_key];
			var strLen = Math.floor(zui.Zui.clamp(Std.parseInt(p_ui.textInput(Id.handle().nest(p_id,{text: modifier.length+""}), "Length", Right)),2,maxGroupSize));

			if( strLen != myarr.length){// Reset element list indexes if needed
				p_elem.modifiers[p_key] = [];
				myarr = [];
				for( y in 0...strLen){
					p_elem.modifiers[p_key].push(makeElem(ElementType.getType(p_elem.modifiers['elementType'])));
				}
			}

			for( i in 0...myarr.length){
				if(p_ui.panel(Id.handle().nest(myarr[i].id),myarr[i].name,5,false)){
					drawElementProperties(myarr[i], p_ui, true);
				} 
			}
		}


	}
	function drawElementProperties(elem: TElement, ui: Zui, isSubElement = false){
		var id = elem.id;
		if(isSubElement){
			ui.row([1/2, 1/2]);
		}
		elem.name = ui.textInput(Id.handle().nest(id, {text: elem.name}), "Name", Right);
		elem.event = ui.textInput(Id.handle().nest(id, {text: elem.event}), "Event", Right);
		ui.row([1/2, 1/2]);
		var handlex = Id.handle().nest(id, {text: elem.x + ""});
		var handley = Id.handle().nest(id, {text: elem.y + ""});
		// if (drag) {
			handlex.text = elem.x + "";
			handley.text = elem.y + "";
		// }
		var strx = ui.textInput(handlex, "X", Right);
		var stry = ui.textInput(handley, "Y", Right);
		elem.x = Std.parseFloat(strx);
		elem.y = Std.parseFloat(stry);
		ui.row([1/2, 1/2]);
		var handlew = Id.handle().nest(id, {text: elem.width + ""});
		var handleh = Id.handle().nest(id, {text: elem.height + ""});
		// if (drag) {
			handlew.text = elem.width + "";
			handleh.text = elem.height + "";
		// }
		var strw = ui.textInput(handlew, "Width", Right);
		var strh = ui.textInput(handleh, "Height", Right);
		elem.width = Std.int(Std.parseFloat(strw));
		elem.height = Std.int(Std.parseFloat(strh));
		elem.text = ui.textInput(Id.handle().nest(id, {text: elem.text}), "Text", Right);
		var assetPos = ui.combo(Id.handle().nest(id, {position: getAssetIndex(elem.asset)}), getEnumTexts(), "Asset", true, Right);
		elem.asset = getEnumTexts()[assetPos];
		if (!isSubElement){
			elem.color = Ext.colorWheel(ui, Id.handle().nest(id, {color: 0xffffff}), true, null, true);
			ui.text("Anchor");
			var hanch = Id.handle().nest(id, {position: elem.anchor});
			ui.row([4/11,3/11,4/11]);
			ui.radio(hanch, 0, "Top-Left");
			ui.radio(hanch, 1, "Top");
			ui.radio(hanch, 2, "Top-Right");
			ui.row([4/11,3/11,4/11]);
			ui.radio(hanch, 3, "Left");
			ui.radio(hanch, 4, "Center");
			ui.radio(hanch, 5, "Right");
			ui.row([4/11,3/11,4/11]);
			ui.radio(hanch, 6, "Bot-Left");
			ui.radio(hanch, 7, "Bottom");
			ui.radio(hanch, 8, "Bot-Right");
			elem.anchor = hanch.position;
		}
		var p_id = -1*id;
		for(key in elem.modifiers.keys()){
			ui.text(key);
			drawModifier(p_id,ui,key,elem);
			p_id += -1;

		}
	}

	var selectedElem = -1;
	var hwin = Id.handle();
	var hradio = Id.handle();
	var lastW = 0;
	var lastH = 0;
	var lastCanvasW = 0;
	var lastCanvasH = 0;
	public function render(framebuffer: kha.Framebuffer): Void {

		if (dropPath != "") {
			importAsset(dropPath);
			dropPath = "";
		}

		// Grid
		if (grid == null) drawGrid();

		var g = framebuffer.g2;

		g.begin();

		g.color = 0xffffffff;
		g.drawImage(grid, 0, 0);

		g.font = kha.Assets.fonts.DroidSans;
		g.fontSize = 40;
		var title = canvas.name + ", " + canvas.width + "x" + canvas.height;
		var titlew = g.font.width(40, title);
		var titleh = g.font.height(40);
		g.color = 0xffffffff;
		g.drawString(title, kha.System.windowWidth() - titlew - 30 - uiw, kha.System.windowHeight() - titleh - 10);
		
		Canvas.screenW = canvas.width;
		Canvas.screenH = canvas.height;
		Canvas.draw(cui, canvas, g);

		// Outline selected elem
		if (selectedElem >= 0 && selectedElem < canvas.elements.length) {
			var elem = canvas.elements[selectedElem];
			g.color = 0xffffffff;
			g.drawRect(canvas.x + elem.x, canvas.y + elem.y, elem.width, elem.height, 1);
			g.drawRect(canvas.x + elem.x - 3, canvas.y + elem.y - 3, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width / 2, canvas.y + elem.y - 3, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width, canvas.y + elem.y - 3, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3, canvas.y + elem.y - 3 + elem.height / 2, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width, canvas.y + elem.y - 3 + elem.height / 2, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3, canvas.y + elem.y - 3 + elem.height, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width / 2, canvas.y + elem.y - 3 + elem.height, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width, canvas.y + elem.y - 3 + elem.height, 6, 6, 1);
		}

		g.end();

		ui.begin(g);
		if (ui.window(hwin, kha.System.windowWidth() - uiw, 0, uiw, kha.System.windowHeight(), false)) {

			var htab = Id.handle();
			if (ui.tab(htab, "Project")) {

				if (ui.button("Save")) {
					// untyped __js__("const {dialog} = require('electron').remote");
					// untyped __js__("console.log(dialog.showSaveDialog({properties: ['saveFile', 'saveDirectory']}))");
					// untyped __js__("var fs = require('fs')");
					// untyped __js__("fs.writeFileSync({0}, {1})", Main.prefs.path, haxe.Json.stringify(canvas));
					
					// Unpan
					canvas.x = 0;
					canvas.y = 0;
					#if kha_krom
					Krom.fileSaveBytes(Main.prefs.path, haxe.io.Bytes.ofString(haxe.Json.stringify(canvas)).getData());
					#end

					var filesPath = Main.prefs.path.substr(0, Main.prefs.path.length - 5); // .json
					filesPath += '.files';
					var filesList = '';
					for (a in canvas.assets) filesList += a.file + '\n';
					#if kha_krom
					Krom.fileSaveBytes(filesPath, haxe.io.Bytes.ofString(filesList).getData());
					#end

					canvas.x = coff;
					canvas.y = coff;
				}

				if (ui.panel(Id.handle({selected: false}), "CANVAS")) {
					// ui.row([1/3, 1/3, 1/3]);
					// if (ui.button("New")) {
					// 	untyped __js__("const {dialog} = require('electron').remote");
					// 	untyped __js__("dialog.showMessageBox({type: 'question', buttons: ['Yes', 'No'], title: 'Confirm', message: 'Create new canvas?'})");
					// }

					// if (ui.button("Open")) {
					// 	untyped __js__("const {dialog} = require('electron').remote");
					// 	untyped __js__("console.log(dialog.showOpenDialog({properties: ['openFile', 'openDirectory', 'multiSelections']}))");
					// }

					if (ui.button("New")) {
						canvas.elements = [];
						selectedElem = -1;
					}

					canvas.name = ui.textInput(Id.handle({text: canvas.name}), "Name", Right);
					ui.row([1/2, 1/2]);
					var strw = ui.textInput(Id.handle({text: canvas.width + ""}), "Width", Right);
					var strh = ui.textInput(Id.handle({text: canvas.height + ""}), "Height", Right);
					canvas.width = Std.parseInt(strw);
					canvas.height = Std.parseInt(strh);
				}

				ui.separator();

				if (ui.panel(Id.handle({selected: true}), "TREE")) {
					Ext.elementGroup(ui,elementAddGroup);
					var i = canvas.elements.length - 1;
					while (i >= 0) {
						var elem = canvas.elements[i];
						if (ui.radio(hradio, i, elem.name)) selectedElem = i;
						i--;
					}
					var temp1 = ui.t.BUTTON_COL;
					var temp2 = ui.t.BUTTON_HOVER_COL;
					var temp3 = ui.t.BUTTON_PRESSED_COL;
					ui.t.BUTTON_COL = 0xff343436;
					ui.t.BUTTON_HOVER_COL = 0xff444446;
					ui.t.BUTTON_PRESSED_COL = 0xff303030;
					Ext.elementGroup(ui,elementNavGroup);
					ui.t.BUTTON_COL = temp1;
					ui.t.BUTTON_HOVER_COL = temp2;
					ui.t.BUTTON_PRESSED_COL = temp3;
				}

				ui.separator();

				if (ui.panel(Id.handle({selected: true}), "PROPERTIES")) {
					if (selectedElem >= 0) {
						var elem = canvas.elements[selectedElem];
						drawElementProperties(elem,ui);
					}
				}
			}

			if (ui.tab(htab, "Assets")) {
				if (canvas.assets.length > 0) {
					ui.text("Drag images to canvas", zui.Zui.Align.Center, 0xff151515);

					var i = canvas.assets.length - 1;
					while (i >= 0) {
						var asset = canvas.assets[i];
						if (ui.image(getImage(asset)) == State.Started) {
							dragAsset = asset;
						}
						ui.row([7/8, 1/8]);
						asset.name = ui.textInput(Id.handle().nest(asset.id, {text: asset.name}), "", Right);
						assetNames[i] = asset.name;
						if (ui.button("X")) {
							getImage(asset).unload();
							canvas.assets.splice(i, 1);
							assetNames.splice(i, 1);
						}
						i--;
					}
				}
				else {
					ui.text("Drop images  here", zui.Zui.Align.Center, 0xff151515);
				}
			}
		}
		ui.end();

		g.begin(false);
		if (dragAsset != null) {
			var w = Math.min(128, getImage(dragAsset).width);
			var ratio = w / getImage(dragAsset).width;
			var h = getImage(dragAsset).height * ratio;
			g.drawScaledImage(getImage(dragAsset), ui.inputX, ui.inputY, w, h);
		}
		g.end();

		if (lastW > 0 && (lastW != kha.System.windowWidth() || lastH != kha.System.windowHeight())) {
			resize();
		}
		else if (lastCanvasW > 0 && (lastCanvasW != canvas.width || lastCanvasH != canvas.height)) {
			resize();
		}
		lastW = kha.System.windowWidth();
		lastH = kha.System.windowHeight();
		lastCanvasW = canvas.width;
		lastCanvasH = canvas.height;
	}


	function getImage(asset:TAsset):kha.Image {
		return Canvas.assetMap.get(asset.id);
	}

	function removeSelectedElem() {
		canvas.elements.splice(selectedElem, 1);
		if (selectedElem == canvas.elements.length) selectedElem--;
		else if (selectedElem < 0) selectedElem++;
		hradio.position = selectedElem;
	}

	function acceptDrag(index:Int) {
		var elem = makeElem(ElementType.Image);
		elem.asset = assetNames[index];
		elem.x = ui.inputX - canvas.x;
		elem.y = ui.inputY - canvas.y;
		elem.width = getImage(canvas.assets[index]).width;
		elem.height = getImage(canvas.assets[index]).height;
		canvas.elements.push(elem);
		selectedElem = hradio.position = canvas.elements.length - 1;
	}

	public function update() {

		// Drag from assets panel
		if (ui.inputReleased && dragAsset != null) {
			if (ui.inputX < kha.System.windowWidth() - uiw) {
				var index = 0;
				for (i in 0...canvas.assets.length) if (canvas.assets[i] == dragAsset) { index = i; break; }
				acceptDrag(index);
			}
			dragAsset = null;
		}
		if (dragAsset != null) return;

		// Select elem
		if (ui.inputStarted && ui.inputDownR) {
			var i = canvas.elements.length;
			while (--i >= 0) {
				var elem = canvas.elements[i];
				if (ui.inputX > canvas.x + elem.x && ui.inputX < canvas.x + elem.x + elem.width &&
					ui.inputY > canvas.y + elem.y && ui.inputY < canvas.y + elem.y + elem.height &&
					selectedElem != i) {
					selectedElem = hradio.position = i;
					break;
				}
			}
		}

		if (selectedElem >= 0 && selectedElem < canvas.elements.length) {
			var elem = canvas.elements[selectedElem];

			// Drag selected elem
			if (ui.inputStarted &&
				ui.inputX >= canvas.x + elem.x - 3 && ui.inputX <= canvas.x + elem.x + elem.width + 3 &&
				ui.inputY >= canvas.y + elem.y - 3 && ui.inputY <= canvas.y + elem.y + elem.height + 3) {
				drag = true;
				dragLeft = dragRight = dragTop = dragBottom = false;
				if (ui.inputX > canvas.x + elem.x + elem.width - 3) dragRight = true;
				else if (ui.inputX < canvas.x + elem.x + 3) dragLeft = true;
				if (ui.inputY > canvas.y + elem.y + elem.height - 3) dragBottom = true;
				else if (ui.inputY < canvas.y + elem.y + 3) dragTop = true;

			}
			if (ui.inputReleased && drag) {
				drag = false;
			}

			if (drag) {
				hwin.redraws = 2;

				if (dragRight) elem.width += Std.int(ui.inputDX);
				else if (dragLeft) { elem.x += Std.int(ui.inputDX); elem.width -= Std.int(ui.inputDX); }
				if (dragBottom) elem.height += Std.int(ui.inputDY);
				else if (dragTop) { elem.y += Std.int(ui.inputDY); elem.height -= Std.int(ui.inputDY); }
			
				if (!dragLeft && !dragRight && !dragBottom && !dragTop) {
					elem.x += ui.inputDX;
					elem.y += ui.inputDY;
				}
			}

			// Move with arrows
			if (ui.isKeyDown && !ui.isTyping) {
				if (ui.key == kha.input.KeyCode.Left) elem.x--;
				if (ui.key == kha.input.KeyCode.Right) elem.x++;
				if (ui.key == kha.input.KeyCode.Up) elem.y--;
				if (ui.key == kha.input.KeyCode.Down) elem.y++;

				if (ui.key == kha.input.KeyCode.Backspace || ui.char == "x") removeSelectedElem();

				hwin.redraws = 2;
			}
		}
	}
}
