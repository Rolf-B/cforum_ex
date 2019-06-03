import React from "react";

import SuggestionsList from "./SuggestionsList";

const IGNORED_KEYS = [
  // "Backspace",
  "Control",
  "Meta",
  "Alt",
  "Shift",
  "Escape",
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight"
];

const NAV_KEYS = ["ArrowUp", "ArrowDown"];
const TRIGGER_KEYS = ["Tab", "Enter"];

export default class AutocompleteTextarea extends React.Component {
  constructor(props) {
    super(props);

    this.state = { suggestions: [], matching: null, active: null };
    this.textarea = null;

    this.handleKeyUp = this.handleKeyUp.bind(this);
    this.handleKeyDown = this.handleKeyDown.bind(this);
    this.onTrigger = this.onTrigger.bind(this);
    this.ref = this.ref.bind(this);
    this.handleSuggestions = this.handleSuggestions.bind(this);
  }

  cursorPositionChanged(prevState) {
    return (
      prevState.cursorPositionStart !== this.state.cursorPositionStart ||
      prevState.cursorPositionEnd !== this.state.cursorPositionEnd
    );
  }

  componentDidUpdate(prevProps, prevState) {
    if (this.cursorPositionChanged(prevState)) {
      this.textarea.setSelectionRange(this.state.cursorPositionStart, this.state.cursorPositionEnd);
    }
  }

  resetSuggestions() {
    this.setState({ suggestions: [], matching: null, active: null });
  }

  navigate(key) {
    if (key === "ArrowDown") {
      this.setState(oldState => {
        let active;

        if (oldState.active === null) {
          active = 0;
        } else {
          active = oldState.active + 1;
          if (active >= oldState.suggestions.length) {
            active = 0;
          }
        }

        return { active };
      });
    } else {
      this.setState(oldState => {
        let active = oldState.active - 1;
        if (active < 0) {
          active = oldState.suggestions.length - 1;
        }

        return { active };
      });
    }
  }

  triggerCompletion(idx = null) {
    const suggestion = this.state.suggestions[idx !== null ? idx : this.state.active];
    const cursorPosition = this.textarea.selectionStart;
    const currentSubstring = this.props.value.substring(0, cursorPosition);
    const rest = this.props.value.substring(cursorPosition);
    const matchData = currentSubstring.match(this.state.matching.trigger);
    const suggestionValue = this.state.matching.complete(suggestion);
    const newValue = currentSubstring.substr(0, currentSubstring.length - matchData[0].length) + suggestionValue + rest;

    this.props.onComplete(newValue);

    let cursorPositionStart = cursorPosition + suggestionValue.length - matchData[0].length;
    let cursorPositionEnd = cursorPositionStart;

    if (this.state.matching.cursorPosition) {
      const { start, end } = this.state.matching.cursorPosition(
        { start: cursorPositionStart, end: cursorPositionEnd },
        suggestionValue
      );

      cursorPositionStart = start;
      cursorPositionEnd = end;
    }

    this.setState({ cursorPositionStart, cursorPositionEnd });
  }

  handleKeyDown(ev) {
    if (this.state.suggestions.length > 0) {
      if (NAV_KEYS.includes(ev.key)) {
        ev.preventDefault();
        this.navigate(ev.key);
        return;
      }

      if (TRIGGER_KEYS.includes(ev.key) && typeof this.state.active === "number") {
        ev.preventDefault();
        this.resetSuggestions();
        this.textarea.focus();
        this.triggerCompletion();
      }
    }

    this.resetSuggestions();
    this.textarea.focus();
  }

  handleKeyUp(ev) {
    if (IGNORED_KEYS.includes(ev.key)) {
      return;
    }

    const triggers = this.props.triggers;
    const cursorPosition = this.textarea.selectionStart;
    const currentSubstring = this.props.value.substring(0, cursorPosition);

    const matching = triggers.find(trg => currentSubstring.match(trg.trigger));
    if (!matching) {
      this.resetSuggestions();
      return;
    }

    this.setState({ matching, active: null });
    matching.suggestions(RegExp.lastMatch, this.handleSuggestions);
  }

  handleSuggestions(suggestions) {
    this.setState({ suggestions });
  }

  onTrigger(event, idx) {
    event.preventDefault();

    this.resetSuggestions();
    this.textarea.focus();
    this.triggerCompletion(idx);
  }

  ref(ref) {
    this.textarea = ref;
    if (this.props.innerRef) this.props.innerRef(ref);
  }

  render() {
    return (
      <div className="cf-autocomplete-wrapper">
        <textarea
          ref={this.ref}
          value={this.props.value}
          onChange={this.props.onChange}
          onKeyUp={this.handleKeyUp}
          onKeyDown={this.handleKeyDown}
        />
        {this.state.suggestions.length > 0 && (
          <SuggestionsList
            suggestions={this.state.suggestions}
            matching={this.state.matching}
            textarea={this.textarea}
            active={this.state.active}
            onKeyDown={this.handleKeyDown}
            onTrigger={this.onTrigger}
          />
        )}
      </div>
    );
  }
}
