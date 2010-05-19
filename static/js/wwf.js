var Game = Class.create({
  initialize: function (id, last_update, your_turn) {
    this.id = id;
    this.last_update = last_update;
    this.your_turn = your_turn;
    this.tray = $('tray');
    this.board = $('board');
    this.say = $('log_input');
    this.submitting = false;
    this.setupTray();
    this.setupBoard();
    this.startPoll();
    $('recall').observe("click", this.recallPieces.bind(this));
    $('submit').observe("click", this.submitLetters.bind(this));
    $('pass').observe("click", this.passTurn.bind(this));
    $('trade').observe("click", this.startTrade.bind(this));
    $('dialog').down("button").observe("click", function(){$('dialog').hide()});
    $('cancel_trade').observe("click", this.cancelTrade.bind(this));
    $('finish_trade').observe("click", this.tradeLetters.bind(this));
    $('log_input').observe("submit", this.submitMessage.bind(this));
  },

  cancelTrade: function (event) {
    if (event) event.stop();
    $('submit').disabled = null;
    $('pass').disabled = null;
    $('trade').disabled = null;
    $('finish_trade').disabled = "disabled";
    $('cancel_trade').disabled = "disabled";
    this.tray.select(".piece").each(function (piece) {
      piece.removeClassName("trade");
      piece.stopObserving("click", this.handleTradeClick);
    }.bind(this));
  },

  handleTradeClick: function (event) {
    var piece = event.findElement(".piece");
    piece.addClassName("trade");
  },

  startTrade: function (event) {
    event.stop();
    $('submit').disabled = "disabled";
    $('pass').disabled = "disabled";
    $('trade').disabled = "disabled";
    $('finish_trade').disabled = null;
    $('cancel_trade').disabled = null;
    this.tray.select(".piece").each(function (piece) {
      piece.observe("click", this.handleTradeClick);
    }.bind(this));
  },

  recallPieces: function (event) {
    event.stop();
    this.tray.select('.piece').each(function (piece) {
      var storage = piece.getStorage();
      storage.unset("position");
      var home = storage.get("home");
      if (home) {
        piece.setStyle({top: home.top+"px", left: home.left+"px"});
      }
    });
  },

  startPoll: function () {
    clearInterval(this.poll_interval);
    this.poll_interval = setInterval(this.pollState.bind(this), 3000);
  },

  pollState: function () {
    new Ajax.Request("/game/"+this.id+"/state", {
      method: "post",
      parameters: {time: this.last_update},
      onSuccess: function (transport) {
        if (!this.submitting)
          this.handleState(transport);
      }.bind(this)
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
        $('trade').disabled = null;
        $('pass').disabled = null;
        document.title = "(!) Leisurely Letters";
      } else {
        $('submit').disabled = "disabled";
        $('trade').disabled = "disabled";
        $('pass').disabled = "disabled";
        document.title = "Leisurely Letters";
      }
    }
  },

  submitMessage: function (event) {
    event.stop();
    var message = $('message').value;
    $('message').value = "";
    this.submitting = true;
    new Ajax.Request("/say", {
      method: "post",
      parameters: {message: message, game: this.id, time: this.last_update},
      onSuccess: function (transport) {
        this.handleState(transport);
        this.submitting = false;
      }.bind(this)
    });
  },

  displayDialog: function (message) {
    $('dialogmsg').innerHTML = message;
    $('dialog').setStyle({display:"block"});
  },

  submitLetters: function (event) {
    event.stop();
    var positions = this.getPiecePositions();
    if (!positions.length) {
      this.displayDialog("No letters to submit");
      return;
    }
    var data = Object.toJSON(positions);
    this.submitting = true;
    new Ajax.Request("/play", {
      method: "post",
      parameters: {pieces: data, game: this.id, time: this.last_update},
      onError: function (transport) {
        this.submitting = false;
        this.displayDialog("Error submitting letters :-(");
      }.bind(this),
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        if (data.error) {
          this.displayDialog((data.error ? data.error : "Unknown error"));
        }
        else {
          // get new board
          this.handleState(transport);

          // remove pieces that were submitted
          $('tray').select('.piece').each(function (piece) {
            var position = piece.getStorage().get("position");
            if (position) piece.remove();
          });

          if (data.letters) this.updateLetters(data.letters);
        }
        this.submitting = false;
      }.bind(this)
    });
  },

  passTurn: function (event) {
    event.stop();
    new Ajax.Request("/play", {
      method: "post",
      parameters: {pass: true, game: this.id, time: this.last_update},
      onError: function (transport) {
        this.submitting = false;
        this.displayDialog("Error passing turn :-(");
      }.bind(this),
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        if (data.error) {
          this.displayDialog((data.error ? data.error : "Unkown error"));
        }
        else {
          this.handleState(transport);
        }
        this.submitting = false;
      }.bind(this)
    });
  },

  tradeLetters: function (event) {
    event.stop();
    var letters = this.getTradedLetters();
    if (!letters.length) {
      this.displayDialog("No letters to trade");
      return;
    }
    letters = Object.toJSON(letters);
    this.submitting = true;

    new Ajax.Request("/play", {
      method: "post",
      parameters: {trade: letters, game: this.id, time: this.last_update},
      onError: function (transport) {
        this.cancelTrade();
        this.submitting = false;
        this.displayDialog("Error trading letters :-(");
      }.bind(this),
      onSuccess: function (transport) {
        var data = transport.responseText.evalJSON();
        if (data.error) {
          this.displayDialog((data.error ? data.error : "Unkown error"));
        }
        else {
          this.handleState(transport);
          $('tray').select('.piece.trade').invoke("remove");
          $('finish_trade').disabled = "disabled";
          $('cancel_trade').disabled = "disabled";
          if (data.letters) this.updateLetters(data.letters);
        }
        this.submitting = false;
      }.bind(this)
    });
  },

  updateLetters: function (letters) {
    var current_letters = this.tray.select('.piece').collect(function (piece) {
      return piece.down('input').value;
    });
    current_letters.each(function (letter) {
      var index = letters.indexOf(letter);
      if (index != -1) letters.splice(index, 1);
    });
    var tds = this.tray.select("td");
    letters.each(function (letter) {
      var piece = "<div class='piece'>" + letter
                + "<input type='hidden' name='letter' value='" + letter + "' />"
                + "<span class='letter_score'>" + Game.letter_scores[letter] + "</span>"
                + "</div>";
      for (var i = 0; i < tds.length; i++) {
        if (!tds[i].down(".piece")) {
          tds[i].insert(piece);
          new Effect.Highlight(tds[i].down(".piece"));
          this.makeDraggable(tds[i].down(".piece"));
          break;
        }
      }
    }.bind(this));
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

  getTradedLetters: function () {
    return this.tray.select(".piece.trade").collect(function (piece) {
      return piece.down("input").value;
    });
  },

  makeDraggable: function (piece) {
    piece.absolutize();
    new Draggable(piece, {
      onStart: function (piece, event) {
        var storage = piece.element.getStorage();
        storage.unset("position");
      }
    });
  },

  setupTray: function () {
    this.tray.select(".piece").each(function (piece) {
      var storage = piece.getStorage();
      storage.set("home", piece.positionedOffset());
      this.makeDraggable(piece);
    }.bind(this));
  },

  setupBoard: function () {
    $('board').select(".empty").each(function(cell) {
      Droppables.add(cell, {
        accept: "piece",
        hoverclass: "hover",
        onDrop: function (piece, cell, event) {
          var position = piece.positionedOffset(),
              cumulative = piece.cumulativeOffset(),
              cell_cumulative = cell.cumulativeOffset();
          var top_diff = cumulative.top - cell_cumulative.top - 1,
              left_diff = cumulative.left - cell_cumulative.left - 1;
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
