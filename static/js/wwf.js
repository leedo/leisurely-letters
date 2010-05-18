var Game = Class.create({
  initialize: function (id, last_update, your_turn) {
    this.id = id;
    this.last_update = last_update;
    this.your_turn = your_turn;
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
    this.poll_interval = setInterval(this.pollState.bind(this), 3000);
  },

  pollState: function () {
    new Ajax.Request("/game/"+this.id+"/state", {
      method: "post",
      parameters: {time: this.last_update},
      onSuccess: this.handleState.bind(this)
    });
  },

  handleState: function (transport) {
    var data = transport.responseText.evalJSON();
    if (data.last_update)
      this.last_update = data.last_update
    if (data.messages)
      $('messages').insert({top:data.messages});
    if (data.board) {
      $('board').replace(data.board);
      this.setupBoard();
    }
    if (data.game_info) {
      $('game_info').replace(data.game_info);
    }
    if (data.your_turn != this.your_turn) {
      if (data.your_turn) {
        $('submit').disabled = null;
      } else {
        $('submit').disabled = "disabled";
      }
    }
  },

  submitMessage: function (event) {
    event.stop();
    var message = $('message').value;
    $('message').value = "";
    new Ajax.Request("/say", {
      method: "post",
      parameters: {message: message, game: this.id, time: this.last_update},
      onSuccess: this.handleState.bind(this)
    });
  },

  submitLetters: function (event) {
    event.stop();
    var data = Object.toJSON(this.getPiecePositions());
    new Ajax.Request("/play", {
      method: "post",
      parameters: {pieces: data, game: this.id, time: this.last_update},
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        if (data.error) {
          $('dialogmsg').innerHTML = (data.error ? data.error : "Unknown error");
          $('dialog').setStyle({display:"block"});
        }
        else {
          // get new board
          this.handleState(transport);

          // remove pieces that were submitted
          $('tray').select('.piece').each(function (piece) {
            var position = piece.getStorage().get("position");
            if (position) piece.remove();
          });
        }
      }.bind(this)
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
