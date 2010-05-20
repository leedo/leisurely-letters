var Game = Class.create({
  initialize: function (id, your_turn, turn_count, last_msgid, completed) {
    this.id = id;
    this.completed = completed;
    this.your_turn = your_turn;
    this.turn_count = turn_count;
    this.last_msgid = last_msgid;
    this.say = $('log_input');
    this.submitting = false;
    if (!this.completed) {
      this.tray = $('tray');
      this.board = $('board');
      this.setupTray();
      this.setupBoard();
      $('recall').observe("click", this.recallPieces.bind(this));
      $('submit').observe("click", this.submitLetters.bind(this));
      $('pass').observe("click", this.passTurn.bind(this));
      $('forfeit').observe("click", this.forfeitGame.bind(this));
      $('trade').observe("click", this.startTrade.bind(this));
      $('dialog').down("button").observe("click", function(){$('dialog').hide()});
      $('cancel_trade').observe("click", this.cancelTrade.bind(this));
      $('finish_trade').observe("click", this.tradeLetters.bind(this));
    }
    $('log_input').observe("submit", this.submitMessage.bind(this));
    this.startPoll();
  },

  cancelTrade: function (event) {
    if (event) event.stop();
    $('submit').disabled = null;
    $('pass').disabled = null;
    $('trade').disabled = null;
    $('finish_trade').disabled = "disabled";
    $('cancel_trade').disabled = "disabled";
    $('tray').removeClassName('trading');
    this.tray.select(".piece").each(function (piece) {
      piece.removeClassName("trade");
      piece.stopObserving("click", this.handleTradeClick);
    }.bind(this));
  },

  handleTradeClick: function (event) {
    var piece = event.findElement(".piece");
    if (piece) {
      if (piece.hasClassName("trade"))
        piece.removeClassName("trade");
      else
        piece.addClassName("trade");
    }
  },

  startTrade: function (event) {
    event.stop();
    $('submit').disabled = "disabled";
    $('pass').disabled = "disabled";
    $('trade').disabled = "disabled";
    $('finish_trade').disabled = null;
    $('cancel_trade').disabled = null;
    $('tray').addClassName("trading");
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
      parameters: {turn: this.turn_count, msgid: this.last_msgid},
      onSuccess: function (transport) {
        if (!this.submitting)
          this.handleState(transport);
      }.bind(this)
    });
  },

  handleState: function (transport) {
    var data = transport.responseText.evalJSON();
    if (data.last_msgid)
      this.last_msgid = data.last_msgid;
    if (data.turn_count)
      this.turn_count = data.turn_count;
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
        document.title = "(!) Leisurely Letters";
        $('submit').disabled = null;
        $('trade').disabled = null;
        $('pass').disabled = null;
      } else {
        document.title = "Leisurely Letters";
        $('submit').disabled = "disabled";
        $('trade').disabled = "disabled";
        $('pass').disabled = "disabled";
      }
    }
    if (data.completed) {
      this.completed = true;
      ["recall","submit","trade","pass","forfeit","finish_trade","cancel_trade","tray"].each(function(button) {
        $(button).remove();
      });
      $('letters_left').innerHTML = "Game over, man.";
    }
    this.your_turn = data.your_turn;
  },

  submitMessage: function (event) {
    event.stop();
    var message = $('message').value;
    $('message').value = "";
    this.submitting = true;
    new Ajax.Request("/game/"+this.id+"/say", {
      method: "post",
      parameters: {message: message, msgid: this.last_msgid, turn: this.turn_count},
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
    new Ajax.Request("/game/"+this.id+"/play", {
      method: "post",
      parameters: {pieces: data, msgid: this.last_msgid, turn: this.turn_count},
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

  forfeitGame: function (event) {
    event.stop();
    new Ajax.Request("/game/"+this.id+"/play/", {
      method: "post",
      parameters: {forfeit: true, msgid: this.last_msgid, turn: this.turn_count},
      onErrror: function (transport) {
        this.submitting = false;
        this.displayDialog("Error forfeiting :-(");
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

  passTurn: function (event) {
    event.stop();
    new Ajax.Request("/game/"+this.id+"/play", {
      method: "post",
      parameters: {pass: true, msgid: this.last_msgid, turn: this.turn_count},
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

    new Ajax.Request("/game/"+this.id+"/play", {
      method: "post",
      parameters: {trade: letters, msgid: this.last_msgid, turn: this.turn_count},
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
          $('tray').select('.piece').each(function (piece){
            if (piece.hasClassName("trade"))
              piece.remove();
            else
              piece.stopObserving("click", this.handleTradeClick);
          });
          $('finish_trade').disabled = "disabled";
          $('cancel_trade').disabled = "disabled";
          $('tray').removeClassName('trading');
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
          var piece = tds[i].down(".piece");
          new Effect.Highlight(piece);
          piece.getStorage().set("home", piece.positionedOffset());
          this.makeDraggable(piece);
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
              left_diff = cumulative.left - cell_cumulative.left;
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
