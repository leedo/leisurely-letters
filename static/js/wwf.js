var Game = Class.create({
  initialize: function (id, last_update) {
    this.id = id;
    this.last_update = last_update;
    this.tray = $('tray');
    this.board = $('board');
    this.say = $('log_input');
    this.setupTray();
    this.setupBoard();
    this.startPoll();
    $('submit').observe("click", this.submitLetters.bind(this));
    $('dialog').down("button").observe("click", function(){$('dialog').hide()});
    $('log_input').observe("submit", this.submitMessage.bind(this));
  },

  startPoll: function () {
    clearInterval(this.poll_interval);
    this.poll_interval = setInterval(this.pollState.bind(this), 5000);
  },

  pollState: function () {
    new Ajax.Request("/game/"+this.id+"/state", {
      method: "post",
      parameters: {time: this.last_update},
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        $('messages').replace(data.messages);
        $('board').replace(data.board);
        this.setupBoard();
      }.bind(this)
    });
  },

  submitMessage: function (event) {
    event.stop();
    var message = $('message').value;
    $('message').value = "";
    new Ajax.Request("/say", {
      method: "post",
      parameters: {message: message, game: this.id},
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        $('messages').insert({top: data.message});
      }
    });
  },

  submitLetters: function (event) {
    event.stop();
    var data = Object.toJSON(this.getPiecePositions());
    new Ajax.Request("/play", {
      method: "post",
      parameters: {pieces: data, game: this.id},
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        if (data.status == "nok") {
          $('dialogmsg').innerHTML = (data.error ? data.error : "Unknown error");
          $('dialog').setStyle({display:"block"});
        }
        else {
          $('tray').select('.piece').each(function (piece) {
            var position = piece.getStorage().get("position");
            if (position) {
              piece.remove();
            }
          });
        }
      }
    });
  },

  getPiecePositions: function () {
    var played_pieces = [];
    this.tray.select(".piece").each(function (piece) {
      var storage = piece.getStorage();
      var position = storage.get("position");
      var letter = piece.down("input").value;
      if (position) {
        played_pieces.push([letter].concat(position));
      }
    });
    return played_pieces;
  },

  setupTray: function () {
    this.tray.select(".piece").each(function(piece) {
      piece.absolutize();
      new Draggable(piece, {
        onStart: function (piece, event) {
          var storage = piece.element.getStorage();
          storage.unset("position");
        }
      });
    });
  },

  setupBoard: function () {
    $('board').select(".empty").each(function(cell) {
      Droppables.add(cell, {
        accept: "piece",
        onDrop: function (piece, cell, event) {
          var position = piece.positionedOffset();
          var cumulative = piece.cumulativeOffset();
          var cell_cumulative = cell.cumulativeOffset();
          var top_diff = cumulative.top - cell_cumulative.top - 1;
          var left_diff = cumulative.left - cell_cumulative.left - 1;
          var storage = piece.getStorage();
          var y = cell.up("tr").previousSiblings().length;
          var x = cell.previousSiblings().length;
          storage.set("position", [x, y]);
          piece.setStyle({top: position.top - top_diff + "px", left: position.left - left_diff + "px"});
        }
      });
    });
  },
});
