/**
 *  @module tabs
 *
 *
 *  @summary
 *
 *  Replaces internal navigation with a tab interface.
 *
 *
 *  @description
 *
 *  This module creates a tab interface from prepared content. In
 *  case there is a template element with the ID tablist, it will take
 *  this elements content to replace a fallback navigation, which is
 *  presumed to be the previous element sibling of the template. After
 *  replacing the navigation with the tablist and setting up the state,
 *  all but the first elements that are meant to be tabpanels are
 *  hidden. When one of the tabs is activated, the current content
 *  is hidden and the newly selected content is made visible.
 *
 *
 *  @todo
 *
 *  The biggest part of this module must be refactored, because
 *  there have been too many subsequent changes causing disarray,
 *  and ultimately a poor handling of control flow. Additionaly most
 *  of the logic related to keyboard control should not be part of
 *  this module, since it can be reused for other components, too.
 *
 *
 *  @requires aria
 *
 *  @requires browser
 *
 *  @requires elements
 *
 *  @requires events
 *
 *  @requires functional
 *
 *  @requires lists
 *
 *  @requires logic
 *
 *  @requires predicates
 *
 *  @requires selectors
 *
 *
 *
 */





import { role, selected, toggleSelection } from './aria.js';

import { hasHiddenAttribute } from './browser.js';



import {

  children,
  elementSiblings,
  firstElementSibling,
  focus,
  getAttribute,
  lastElementSibling,
  nextElementSibling,
  previousElementSibling,
  setAttribute,
  toggleHiddenState,
  toggleTabIndex

} from './elements.js';



import {

  bind,
  key,
  preventDefault,
  ready,
  target

} from './events.js'



import { compose, memoize, pipe } from './functional.js';

import { find, head, transform } from './lists.js';



import {

  both,
  conditions,
  either,
  unless,
  when

} from './logic.js';



import { defined, equal } from './predicates.js';

import { id } from './selectors.js';





/**
 *  @function addTabBehavior
 *
 *
 *  @summary
 *
 *  Implements tabbing behavior to a given element.
 *
 *
 *  @description
 *
 *  This function takes an element that is meant to be a tab
 *  and registers event handlers for this element. If the element
 *  gets clicked, it is checked if it already is the selected tab,
 *  and if not, this element is activated and the formerly active
 *  tab is disabled. On keydown it is first determined which tab
 *  should be activated next, before selecting the new and
 *  unselecting the old tab.
 *
 *
 *  @param { Element } tab
 *
 *  The tab to add behavior to.
 *
 *
 *  @return { Element }
 *
 *  The element provided to this function.
 *
 *
 *
 */
function addTabBehavior (tab) {
  return bind(tab, {

    click: pipe(preventDefault, target, unless(selected, pipe(historyPushState, switchTabs))),

    keydown: conditions([

      [key('ArrowLeft'),
       switchTo(either(previousElementSibling, lastElementSibling))],

      [key('ArrowRight'),
       switchTo(either(nextElementSibling, firstElementSibling))],

      [key('Home'),
       switchTo(firstElementSibling)],

      [key('End'),
       switchTo(lastElementSibling)]

    ])

  });
}





/**
 *  @function getTabFromPanel
 *
 *
 *  @summary
 *
 *  Returns the tab that controls a panel.
 *
 *
 *  @description
 *
 *  This function takes a panel and returns the tab by which
 *  it is controlled. The function obtains the ID of the tab from
 *  the aria-labelledby attribute of the panel and then references
 *  the element via this identifier. To avoid having to search the
 *  DOM in every invokation, this function is memoized, such that
 *  multiple calls with the same input will read the result from
 *  a cache in all but the first call.
 *
 *
 *  @param { Element } panel
 *
 *  The panel whose associated tab should be returned.
 *
 *
 *  @return { Element }
 *
 *  The tab that controls the panel.
 *
 *
 *
 */
const getTabFromPanel = memoize(pipe(getAttribute('aria-labelledby'), id));





/**
 *  @function getPanelFromTab
 *
 *
 *  @summary
 *
 *  Returns the panel controlled by a tab.
 *
 *
 *  @description
 *
 *  This function takes a tab and returns the panel it controls.
 *  To find the associated panel, the attribute aria-controls of the
 *  tab is used, whose value is an ID reference to the panel. Because
 *  referencing an element by its ID might be a time consuming task,
 *  the function is memoized, so the DOM will only be searched in the
 *  first call. In all subsequent calls with the same input the
 *  result will be read from a cache.
 *
 *
 *  @param { Element } tab
 *
 *  The tab whose associated panel should be returned.
 *
 *
 *  @return { Element }
 *
 *  The panel controlled by the tab.
 *
 *
 *
 */
const getPanelFromTab = memoize(pipe(getAttribute('aria-controls'), id));





/**
 *  @function getPanelFromFragment
 *
 *
 *  @summary
 *
 *  Finds a panel that is referenced by an URL fragment.
 *
 *
 *  @description
 *
 *  This function tests a list of panels against the fragment part
 *  of the pages URL. If there is a fragment and in case the fragment
 *  identifier matches the ID of a panel, this panel will be returned,
 *  otherwise null. The function is needed to enable navigation using
 *  the browser history and to make it possible to directly link to
 *  content that is contained within the tab interface.
 *
 *
 *  @param { Iterable } panels
 *
 *  A list of panels for comparsion.
 *
 *
 *  @return { ? Element }
 *
 *  Either the found panel or null.
 *
 *
 *
 */
const getPanelFromFragment = find(panel => equal(location.hash.slice(1), panel.id));





/**
 *  @function handleHistoryChange
 *
 *
 *  @summary
 *
 *  Restores the selection when the browser history changes.
 *
 *
 *  @description
 *
 *  This module takes care that the currently selected tab and its
 *  associated content are reflected by the pages URL. When the user
 *  presses the back or forward button of her browser, the selection
 *  within the tab interface must be set accordingly. This function
 *  registers a handler that will be called every time the state of
 *  the browsers history changes. It gathers the necessary data
 *  and selects the tab that matches the URLs fragment.
 *
 *
 *  @param { Iterable } panels
 *
 *  A list of tab panels.
 *
 *
 *  @return { Window }
 *
 *  The global object.
 *
 *
 *
 */
function handleHistoryChange (panels) {
  return bind(window, {

    popstate (event) {
      when(defined, switchTabs, compose(getTabFromPanel, getPanelFromFragment, panels));
    }

  });
}





/**
 *  @function getState
 *
 *
 *  @summary
 *
 *  Returns an array with state information obtained from a tab.
 *
 *
 *  @description
 *
 *  This function takes a tab and returns an array containing its
 *  textual content and a string that represents an URL fragment for
 *  the tabs associated panel. These two values are arguments for the
 *  methods of the browsers History API and extracted to avoid code
 *  duplication. The function is only called from the functions
 *  pushState and replaceState that are defined below.
 *
 *
 *  @todo
 *
 *  The function does not look particularly good, but I haven’t come
 *  up with a better solution to handle the subject, yet. If some time
 *  in the future a task requires similar functionality, then it might
 *  be possible to write an abstraction providing an interface which
 *  allows for a less verbose implementation.
 *
 *
 *  @param { Element } tab
 *
 *  The tab to obtain arguments for the History API from.
 *
 *
 *  @return { Array }
 *
 *  A list with arguments for the History API.
 *
 *
 *
 */
const getState = tab => [tab.textContent, '#' + getAttribute('aria-controls', tab)];





/**
 *  @function historyPushState
 *
 *
 *  @summary
 *
 *  Adds a new entry to the browsers history.
 *
 *
 *  @description
 *
 *  This function is a wrapper for the pushState method that is
 *  provided by the browsers History API. It takes a tab and retrieves
 *  its text content for a title as well as an ID reference to the panel
 *  that is controlled by the tab. The panels identifier is then used
 *  to create an URL fragment by combining it with a hash sign.
 *
 *
 *  Subsequently the pushState method is called with both these values
 *  to create a new entry in the browsers history. Then the supplied tab
 *  is returned. The purpose of this function is to let the URL of the
 *  page reflect the current tab selection, such that it is possible
 *  to navigate using the browsers back and forward buttons.
 *
 *
 *  @param { Element } tab
 *
 *  The tab whose properties shoud be used in the browser history.
 *
 *
 *  @return { Element }
 *
 *  The provided tab.
 *
 *
 *
 */
function historyPushState (tab) {
  history.pushState({}, ...getState(tab));
  return tab;
}





/**
 *  @function historyReplaceState
 *
 *
 *  @summary
 *
 *  Replaces the current entry in the browsers history.
 *
 *
 *  @description
 *
 *  When the page containing the tab interface is loaded the first
 *  time then there are two possibilities. Either the URL of the page
 *  does not include a fragment part matching an ID of a panel, which
 *  means the first tab should be selected, or it does have a relevant
 *  fragment identifier which can be used to determine which tab
 *  should be selected.
 *
 *
 *  In both cases this function is called to replace the current
 *  entry in the browsers history by calling the native replaceState
 *  method of the History API. The new entry will be equipped with an
 *  appropriate title obtained from the tabs text content and the
 *  correct URL reflecting the currently selected tab.
 *
 *
 *  @param { Element } tab
 *
 *  The tab whose properties shoud be used in the browser history.
 *
 *
 *  @return { Element }
 *
 *  The provided tab.
 *
 *
 *
 */
function historyReplaceState (tab) {
  history.replaceState({}, ...getState(tab));
  return tab;
}





/**
 *  @function toggleTab
 *
 *
 *  @summary
 *
 *  Changes the state of a tab and its associated panel.
 *
 *
 *  @description
 *
 *  This function enables or disables a tab depending on the tabs
 *  current state. If the tab is currently selected, then its aria
 *  selected attribute will be set to false and it will be removed
 *  from the documents taborder. In addition, the hidden attribute
 *  of the panel that is controlled by the tab is set, such that
 *  the panel is no longer visible. In case the tab is not
 *  selected, the opposite will happen.
 *
 *
 *  @param { Element } tab
 *
 *  A selected or unselected tab.
 *
 *
 *  @return { Element }
 *
 *  The tabpanel that is controlled by the tab.
 *
 *
 *
 */
const toggleTab = pipe(toggleSelection, toggleTabIndex, getPanelFromTab, toggleHiddenState);





/**
 *  @function switchTo
 *
 *
 *  @summary
 *
 *  Switches between two tabs when a key was pressed.
 *
 *
 *  @description
 *
 *  In case a keydown event occurs on the currently selected tab,
 *  it must be determined which tab should be activated next. So this
 *  function takes a callback which is called with a reference to the
 *  currently selected tab. The return value of this selector function
 *  is expected to be the tab that is the target of the operation.
 *  Then this function removes the old selection and changes the
 *  state of the tab provided by the callback to selected.
 *
 *
 *  @param { function } selector
 *
 *  A function that returns the tab that should be selected.
 *
 *
 *  @return { Element }
 *
 *  The panel of the newly selected tab.
 *
 *
 *
 */
function switchTo (selector) {
  return pipe(
    preventDefault, target,
    selector, when(defined, pipe(historyPushState, switchTabs))
  );
}





/**
 *  @function switchTabs
 *
 *
 *  @summary
 *
 *  Disables the active tab and enables the selected tab.
 *
 *
 *  @description
 *
 *  This function takes the newly selected tab and returns the panel
 *  which is associated with it. When called, the first thing it does
 *  is to find out which tab is currently selected and disables it by
 *  changing some of its attributes values and hiding the panel that
 *  is controlled by this tab. Thereafter the tab the function has
 *  been called with is focussed and made the current selection.
 *
 *
 *  @param { Element } tab
 *
 *  The newly selected tab.
 *
 *
 *  @return { Element }
 *
 *  The tabpanel associated with the selected tab.
 *
 *
 *
 */
function switchTabs (tab) {
  return toggleTab(compose(find(selected), elementSiblings, tab)), toggleTab(focus(tab));
}





/**
 *  @function setupTabInterface
 *
 *
 *  @summary
 *
 *  Implements the logic for the tab interface.
 *
 *
 *  @description
 *
 *  This function expects to be called with a reference to the
 *  template whose content is the prepared tablist. It replaces
 *  the fallback for the tab interface with the retrieved tablist,
 *  complements missing attributes on the elements that should be
 *  tabs and panels, and registers event handlers on the tabs
 *  to make these elements interactive.
 *
 *
 *  @param { HTMLTemplateElement } template
 *
 *  The template for the tablist.
 *
 *
 *  @return { Element }
 *
 *  The selected tab panel.
 *
 *
 *
 */
function setupTabInterface (template) {
  return compose(
    both(handleHistoryChange, makeInitialSelection), setupTabsAndPanels,
    insertTablist(template)
  );
}





/**
 *  @function insertTablist
 *
 *
 *  @summary
 *
 *  Replaces the fallback navigation with a tablist.
 *
 *
 *  @description
 *
 *  This function is called with a reference to a template element
 *  whose content is expected to be a prepared tablist. It replaces
 *  the existing fallback for the tab interface with the tablist that
 *  is retrieved from the template. It is presumed that the fallback
 *  will be a single element that is the previous element sibling of
 *  the template. So, explicit marking of the fallback content is
 *  not necessary. After the replacement the template element
 *  will be removed from the document.
 *
 *
 *  @param { HTMLTemplateElement } template
 *
 *  The template to use.
 *
 *
 *  @return { Element }
 *
 *  The tablist inserted into the document.
 *
 *
 *
 */
function insertTablist (template) {
  const tablist = template.content.firstElementChild;

  template.parentNode.replaceChild(tablist, template.previousElementSibling), template.remove();
  return tablist
}





/**
 *  @function setupTabsAndPanels
 *
 *
 *  @summary
 *
 *  Initializes the elements to serve as tab and panels.
 *
 *
 *  @description
 *
 *  This function takes the tablist and returns an array with
 *  tab panels. It registers event handlers for each tab and sets
 *  roles and labels to the panels that are controlled by the tabs.
 *  In addition, all panels will be disabled and made invisible by
 *  setting the attribute hidden on them. In accordance with the
 *  predefined tablist markup, all tabs and corresponding panels
 *  will be disabled after calling this function.
 *
 *
 *  @param { Element } tablist
 *
 *  The element that serves as tablist.
 *
 *
 *  @return { Element [] }
 *
 *  An array with elements transformed to tab panels.
 *
 *
 *
 */
function setupTabsAndPanels (tablist) {
  return transform(
    pipe(addTabBehavior, setRoleAndLabelForPanel, toggleHiddenState),
    children(tablist)
  );
}




/**
 *  @function setRoleAndLabelForPanel
 *
 *
 *  @summary
 *
 *  Sets the appropriate role and labels a tab panel.
 *
 *
 *  @description
 *
 *  To be recognized as a tabpanel by assistive software, the
 *  elements which are meant to play this role must be marked up
 *  accordingly. This function takes a designated tab, references
 *  its associated tab panel via the value of its aria-controls
 *  attribute and adds the role tabpanel to this element. To
 *  provide an accessible name, the tab panel is labeled by
 *  the corresponding tabs text content.
 *
 *
 *  @param { Element } tab
 *
 *  The tab whose associated panel to set up.
 *
 *
 *  @return { Element }
 *
 *  The initialized panel.
 *
 *
 *
 */
function setRoleAndLabelForPanel (tab) {
  return compose(role('tabpanel'), setAttribute('aria-labelledby', tab.id), getPanelFromTab(tab));
}





/**
 *  @function determineActiveTab
 *
 *
 *  @summary
 *
 *  Returns the tab that should be selected on page load.
 *
 *
 *  @description
 *
 *  This function takes a list of tab panels and returns the tab
 *  that should be initially selected. If the pages URL contains a
 *  fragment from which an identifier for a panel can be retrieved,
 *  then the tab associated with this panel will be returned, else
 *  the tab that controls the first panel. This way the user can
 *  directly link to content contained in the tab interface.
 *
 *
 *  @param { Element [] } panels
 *
 *  The list of tab panels.
 *
 *
 *  @return { Element }
 *
 *  An element representing a tab.
 *
 *
 *
 */
const determineActiveTab = pipe(either(getPanelFromFragment, head), getTabFromPanel);





/**
 *  @function makeInitialSelection
 *
 *
 *  @summary
 *
 *  Enables the requested or first tab on page load.
 *
 *
 *  @description
 *
 *  When setting up the tabs and panels, initially all tabs are
 *  disabled. Now, this function is used to determine which of the
 *  tab panels should be visible and to enable the corresponding tab.
 *  In case the pages URL has a fragment whose identifier can be used
 *  to determine the tab that should be selected, this tab will be
 *  enabled, otherwise the first tab in the list. In addition, the
 *  function historyReplaceState will be called to update the
 *  entry in the browsers history.
 *
 *
 *  @param { Element [] } panels
 *
 *  The list of tab panels.
 *
 *
 *  @return { Element }
 *
 *  The panel controlled by the selected tab.
 *
 *
 *
 */
const makeInitialSelection = pipe(determineActiveTab, historyReplaceState, toggleTab);





/**
 *  @function main
 *
 *
 *  @summary
 *
 *  Entry point for the program.
 *
 *
 *  @description
 *
 *  This function is executed When the DOM is fully loaded and
 *  parsed. It first checks if the hidden attribute is supported
 *  and then sets up the tab interface. In the future the feature
 *  check might be excluded, but we decided to keep it in for now
 *  to avoid having users be exposed to a dysfunctional interface.
 *  If the hidden attribute is not supported, the user has to
 *  use the fallback navigation.
 *
 *
 *  @param { Event } event
 *
 *  An event object.
 *
 *
 *  @callback
 *
 *
 *
 */
ready(function main (event) {
  when(both(defined, hasHiddenAttribute), setupTabInterface, id('tablist'));
});
