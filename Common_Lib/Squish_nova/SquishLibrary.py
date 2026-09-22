"""
This is Robot Framework python library for interfacing with Squish framework.

For clarification, most methods accepts object_real_name parameter which is value in form of dictionary stored in object
 repository and assigned to symbolic name. Object repository is stored at Common_Lib/Squish/Object_Repository package.
 Object Repository contains pairs of object_symbolic_name and respective object_real_name.
object_symbolic_name is in form e.g.: "caseScreen_CaseScreen" which is variable name.
Here is a link to documentation about what are symbolic names and real names in Squish framework:
https://qatools.knowledgebase.qt.io/squish/howto/symbolic-object-name/

Some of the methods which are not intended to use at Robot Framework level accepts object_reference parameter, its
object reference which Squish framework returns to entities which are present in ui application.
"""


import os
import sys
import datetime
from typing import Union, Any
from robot.api import logger as rf_logger
import squishtest           # DIRs which contains squishtest must be in PYTHONPATH
from SquishUtilLibrary import SquishUtilLibrary as util


# Set expected environment variable name which will hold path for SQUISH internal reports
SQUISH_REPORTS_DIR_ENV_NAME = "SQUISH_REPORTS_DIR"


class SquishLibrary:
    """Squish Library for use with the Robot Framework"""

    ROBOT_LIBRARY_SCOPE = 'TEST CASE'

    def __init__(self):
        pass

    def attach_to_aut(self, aut: str, wrapper: str):
        """Attaches itself to running AUT, args=(aut, wrapper)"""
        print("*INFO* Attaching to AUT: %s with %s wrapper" % (aut, wrapper))
        # Remove double quotes for setWrappersForApplication
        aut = aut.replace('"', '')

        # Fixed example from QT (needed to pass wrapper object inside list)
        squishtest.testSettings.setWrappersForApplication(aut, [wrapper])

        squishtest.setDebugFlags("alpw")

        # Launch the application:
        squishtest.attachToApplication(aut)

    def detach_from_aut(self):
        """Detaches itself from AUT"""
        app_context = squishtest.currentApplicationContext()
        if app_context.isRunning:
            app_context.detach()

    def get_property(self, object_real_name: dict, property_path: str, wait_for_object_to_be_visible: bool) \
            -> Union[str, bool, int, float, dict, None]:
        """Acquire reference to Qt UI object by ``object_real_name`` parameter, fetches ``property_path`` value and
        returns it.
        The way how the object reference is gained it is based on ``wait_for_object_to_be_visible`` flag. When its value
        is ``True`` then Squish is trying to fetch object which is enabled and visible. When set to ``False`` Squish
        returns referenced object even if it is not visible and not enabled.
        ``property_path`` value can hold path to property joined by dot separator e.g.: ``font.family``.
        This allows to access nested properties if user knows that some object contains property inside another
        property like in aforementioned ``family.font`` example.

        When ``property_path`` does not exist in referenced object ``None`` value is returned.

        Example:\n
        obj = SquishLibrary()\n
        obj.attach_to_aut('CatheterModel', 'Qt')\n
        electrodeD1Label_Text = {"container": electrodeD1_Electrode, "objectName": "electrodeD1Label", "type": "Text"}
        obj.get_property(electrodeD1Label_Text, 'font.family')\n
        obj.detach_from_aut()
        """
        print("*INFO* Got arguments: %s, %s" % (object_real_name, property_path))
        object_reference = self.get_object_reference(object_real_name, wait_for_object_to_be_visible)
        try:
            prop = self._get_nested_property(object_reference, property_path)
        except AttributeError as e:
            # specified property is not present in referenced object
            print(f"*ERROR* {object_real_name=} does not contain {property_path=}. Original error: {e}")
            return None
        # determine type of object which is returned by Squish Framework
        prop_type = squishtest.className(prop)
        if prop_type == 'QString':
            # if its simply string object, cast it to str type
            return str(prop)
        elif prop_type in ('bool', 'int', 'float'):
            # if its bool, int or float, just let it be returned
            return prop
        else:
            # if its more complex just returned it as dict of properties of referenced property path
            return self._get_object_properties(prop)

    def set_property(self, object_real_name: dict, prop: str, value: Any):
        """Sets ``prop`` to ``value`` inside referenced object via ``object_real_name``."""
        print(f"*INFO* Got arguments: %s, %s, %s" % (object_real_name, prop, value))
        obj = squishtest.waitForObject(object_real_name)
        print(f"*INFO*  debug: {prop=} and its {value=} is {type(value)=}")
        obj.setProperty(prop, value)

    def get_application_context_info(self) -> str:
        """Method which simply provides information about attached application."""
        app_context = squishtest.currentApplicationContext()
        if app_context is not None:
            dt_object = datetime.datetime.fromtimestamp(app_context.startTime)
            formatted_date = dt_object.strftime("%Y-%m-%d %H:%M:%S")

            info_str = f"Attachable AUT name: {app_context.name}\r\n" + \
                       f"AUT current cwd: {app_context.cwd}\r\n" + \
                       f"OS system on which AUT runs: {app_context.osName}\r\n" + \
                       f"Start time of AUT: {formatted_date}\r\n" + \
                       f"Total time of AUT running: {app_context.totalTime}"
            return info_str

    def get_object_global_bounds(self, object_reference) -> squishtest.UiTypes.ScreenRectangle:
        """Using provided ``object_reference`` get its global bounds as ScreenRectangle object."""
        return squishtest.object.globalBounds(object_reference)

    def fail(self, message: str):
        """This method is intended for marking failure during test. It provides possibility to save screenshot of
        AUT via squish internal mechanism."""
        # by using this method we are forcing squish to note the fail and as result take a screenshot at this stage
        squishtest.test.fail(message)
        # propagate error for robot framework by using exception
        raise AssertionError(message)

    def click_button(self, object_real_name: dict):
        """Clicks on Qt button, args=(object_real_name). For this method to actually work, referenced object via
        `object_real_name` must be derived from Qt Button class."""
        squishtest.clickButton(squishtest.waitForObject(object_real_name))

    def mouse_move(self, object_real_name: dict):
        """Moves mouse to object_real_name position."""
        squishtest.mouseMove(squishtest.waitForObject(object_real_name))

    def mouse_click(self, object_real_name: dict, **kwargs):
        """Clicks in position of object which is referenced by `object_real_name`.
        Optionally accepts x, y, modifier, button as keyword arguments.
        """
        keys = ('x', 'y', 'modifier', 'button')
        obj_to_be_clicked = self.get_object_reference(object_real_name, True)
        if not any(k in kwargs and kwargs[k] not in [None, ''] for k in keys):
            print(f"*INFO* mouse_click got no kwargs, clicking default way at the center of object.")
            self.mouse_click_object_reference(obj_to_be_clicked)
        else:
            print(f"*INFO* mouse_click got kwargs: {kwargs}")
            x_val = int(kwargs.get('x', 0) or 0)
            y_val = int(kwargs.get('y', 0) or 0)
            modifier_val = int(kwargs.get('modifier', 0) or 0)
            button_val = int(kwargs.get('button', 1) or 1)
            self.mouse_click_object_reference(obj_to_be_clicked, x_val, y_val, modifier_val, button_val)

    def mouse_click_object_reference(self, object_reference, x: int = 0, y: int = 0, modifier=0, button=1):
        """Clicks in position of `object_reference`."""
        squishtest.mouseClick(object_reference, x, y, modifier, button)

    def mouse_click_at_coordinates(self, x: int, y: int, modifier=0, button=1):
        """Clicks at given screen coordinates (x,y)."""
        screen_point = squishtest.UiTypes.ScreenPoint(x, y)
        squishtest.mouseClick(screen_point, modifier, button)

    def enter(self, object_real_name: dict, txt: str):
        """Enters given text into TextField, args=(object_real_name, txt)"""
        print('*INFO* Entering "%s" into object "%s"' % (txt, object_real_name))
        squishtest.type(squishtest.waitForObject(object_real_name), txt)

    def get_object_property(self, object_reference, prop: str):
        """Using ``object_reference`` which holds real Qt object access its ``prop``"""
        return getattr(object_reference, prop)

    def _get_object_properties(self, object_reference):
        """Using ``object_reference`` which holds real Qt object access its all properties."""
        return squishtest.object.properties(object_reference)

    def _get_nested_property(self, object_reference, property_path: Union[str, list]):
        """Recursively fetches the last property provided in ``property_path`` in ``object_reference``."""
        if isinstance(property_path, str):
            property_path = property_path.split(sep='.')
        current_property = property_path.pop(0)

        value = self.get_object_property(object_reference, current_property)
        if property_path:
            return self._get_nested_property(value, property_path)
        return value

    def get_object_reference(self, object_real_name: dict, should_be_visible_and_enabled: bool):
        """Using provided ``object_real_name`` get a Qt ``object reference`` and return it for further usage.
        Object reference can be returned even if it is not visible and not enabled. This behavior can be achieved
        by using ``should_be_visible_and_enabled`` flag set to ``False``."""
        if should_be_visible_and_enabled:
            obj = squishtest.waitForObject(object_real_name)
        else:
            obj = squishtest.waitForObjectExists(object_real_name)
        return obj

    def wait_until_not_visible(
            self,
            object_real_name: dict,
            timeout_ms: int = 2000,
            poll_interval_ms: int = 100,
            treat_not_exists_as_not_visible: bool = True,
    ) -> bool:
        """Waits until the referenced object is not visible (or gone)."""
        import time

        end_time = time.time() + (timeout_ms / 1000.0)

        while time.time() < end_time:
            try:
                obj = squishtest.waitForObjectExists(object_real_name)
            except Exception:
                if treat_not_exists_as_not_visible:
                    return True
                time.sleep(poll_interval_ms / 1000.0)
                continue

            visible = bool(getattr(obj, "visible"))
            if not visible:
                return True

            time.sleep(poll_interval_ms / 1000.0)

        raise TimeoutError(f"Timed out waiting for {object_real_name} to become not visible")

    # ListView specific methods:
    def listview_increment_current_index(self, object_real_name: dict) -> int:
        """Increments current index of object referenced by `object_real_name` and returns new current index value."""
        ref = self.get_object_reference(object_real_name, True)
        if hasattr(ref, 'incrementCurrentIndex'):
            if ref.currentIndex >= ref.count:
                raise IndexError(f"Cannot increment current index of {object_real_name}, already at maximum index.")
            ref.incrementCurrentIndex()
            return ref.currentIndex
        else:
            raise AttributeError(f"Referenced object {object_real_name} does not have method 'incrementCurrentIndex'")

    def listview_decrement_current_index(self, object_real_name: dict) -> int:
        """Decrements current index of object referenced by `object_real_name` and returns new current index value."""
        ref = self.get_object_reference(object_real_name, True)
        if hasattr(ref, 'decrementCurrentIndex'):
            if ref.currentIndex <= 0:
                raise IndexError(f"Cannot decrement current index of {object_real_name}, already at minimum index.")
            ref.decrementCurrentIndex()
            return ref.currentIndex
        else:
            raise AttributeError(f"Referenced object {object_real_name} does not have method 'decrementCurrentIndex'")

    def listview_get_count(self, object_real_name: dict) -> int:
        """Returns count of items in ListView referenced by `object_real_name`."""
        ref = self.get_object_reference(object_real_name, True)
        if hasattr(ref, 'count'):
            return ref.count
        else:
            raise AttributeError(f"Referenced object {object_real_name} does not have property 'count'")

    def listview_position_view_at_index(self, object_real_name: dict, index: int):
        """Positions view at specified `index` in ListView referenced by `object_real_name`."""
        ref = self.get_object_reference(object_real_name, True)
        if hasattr(ref, 'positionViewAtIndex'):
            if index < 0 or index >= ref.count:
                raise IndexError(f"Index {index} is out of bounds for ListView with count {ref.count}.")
            ref.positionViewAtIndex(index, squishtest.QQuickListView.Contain)
        else:
            raise AttributeError(f"Referenced object {object_real_name} does not have method 'positionViewAtIndex'")

    def listview_click_current_item(self, object_real_name: dict):
        """Clicks on the current item in ListView referenced by `object_real_name`."""
        list_view_obj = self.get_object_reference(object_real_name, True)
        current_item = list_view_obj.currentItem
        self.mouse_click_object_reference(current_item, 0, 0, 0, 1)

    def listview_select_next_item(self, object_real_name: dict):
        """Selects the next item in ListView referenced by `object_real_name`."""
        list_view_obj = self.get_object_reference(object_real_name, True)
        current_index = self.listview_increment_current_index(object_real_name)
        self.listview_position_view_at_index(object_real_name, current_index)
        current_item = list_view_obj.currentItem
        self.mouse_click_object_reference(current_item, 0, 0, 0, 1)

    def listview_select_previous_item(self, object_real_name: dict):
        """Selects the previous item in ListView referenced by `object_real_name`."""
        list_view_obj = self.get_object_reference(object_real_name, True)
        current_index = list_view_obj.currentIndex

        if current_index == 0:
            rf_logger.warn(f"{current_index=} of ListView {object_real_name} is already at the first item, cannot select previous item.")
            raise IndexError(f"Cannot decrement current index of {object_real_name}, already at minimum index.")
        else:
            current_index = self.listview_decrement_current_index(object_real_name)
            self.listview_position_view_at_index(object_real_name, current_index)
            current_item = list_view_obj.currentItem
            self.mouse_click_object_reference(current_item, 0, 0, 0, 1)

    def listview_select_item_by_text(self, object_real_name: dict, item_text: str):
        """Selects an item by its text in ListView referenced by `object_real_name`."""
        list_view_obj = self.get_object_reference(object_real_name, True)
        item_count = self.listview_get_count(object_real_name)

        # make sure we are at the start of the list
        list_view_obj.currentIndex = 0

        for row in range(item_count):
            # position view at the current index to ensure item is visible
            self.listview_position_view_at_index(object_real_name, list_view_obj.currentIndex)

            item = list_view_obj.currentItem
            text = str(item.modelData)
            if item_text == text:
                self.listview_click_current_item(object_real_name)
                return row

            # increment current index for next iteration
            self.listview_increment_current_index(object_real_name)
        else:
            return None

    def _date_picker_click_delegate(self, delegates: list, target_text: str, delegate_label: str):
        """
        Shared logic for clicking a date picker delegate (day/month/year).
        Finds the child QQuickText, compares text, clicks, and verifies selection.

        Args:
            delegates: List of delegate objects (pre-filtered).
            target_text: The text value to match and click.
            delegate_label: Label used in error messages (e.g. 'day', 'month', 'year').
        """
        if not delegates:
            raise RuntimeError(f"Could not find {delegate_label} delegate with text: {target_text}")

        delegate = delegates.pop()

        child = self.find_child_by_type(delegate, "QQuickText")
        if child is None:
            raise RuntimeError(
                f"Could not find child with type QQuickText in {delegate_label} delegate for {delegate_label} text: {target_text}"
            )

        text = str(child.text)
        if text != target_text:
            raise RuntimeError(f"Could not find and click {delegate_label}: {target_text}")

        self.mouse_click_object_reference(delegate, delegate.width / 2, delegate.height / 2)

    def date_picker_get_items_by_text(self, items_real_name: dict, text: str):
        """Returns list of items objects from DatePicker which has `text` property equal to provided
        `text`."""
        results = []
        item_list = squishtest.findAllObjects(items_real_name)
        for item in item_list:
            if self.find_child_by_property(item, "QQuickText", "text", text) is not None:
                results.append(item)
        return results

    def date_picker_get_delegate_info(self, delegate_object_reference) -> dict:
        """Returns dict with info about date picker delegate like text, isCurrentMonth, isSelected, isSavedDate,
        isSavedYear."""
        delegate_info = {}
        child = self.find_child_by_type(delegate_object_reference, "QQuickText")
        delegate_info['text'] = str(child.text) if child is not None else None

        for prop in ('isCurrentMonth', 'isSavedDate', 'isSavedYear', 'isSelected', 'visible'):
            raw = getattr(delegate_object_reference, prop, None)
            delegate_info[prop] = bool(raw) if raw is not None else None
        return delegate_info

    def date_picker_get_days_by_text(self, days_real_name: dict, day_text: str, filter_mode: str = "current_month_only") -> list:
        day_delegates = self.date_picker_get_items_by_text(days_real_name, day_text)
        if filter_mode.lower() == 'current_month_only':
            current_month_delegates = [d for d in day_delegates if d.isCurrentMonth]
        elif filter_mode.lower() == 'beyond_current_month_only':
            current_month_delegates = [d for d in day_delegates if not d.isCurrentMonth]
        elif filter_mode.lower() == 'all':
            current_month_delegates = day_delegates
        else:
            raise ValueError(f"Invalid filter_mode: {filter_mode}. Expected 'current_month_only', "
                             f"'beyond_current_month_only' or 'all'.")

        return current_month_delegates

    def date_picker_click_day_by_text(self, days_real_name: dict, day_text: str, filter_mode: str = "current_month_only"):
        days_delegates = self.date_picker_get_days_by_text(days_real_name, day_text, filter_mode)
        self._date_picker_click_delegate(days_delegates, day_text, "day")

    def date_picker_click_month_by_text(self, months_real_name: dict, month_text: str):
        normalized_month_text = month_text.strip()[:3].capitalize()
        month_delegates = self.date_picker_get_items_by_text(months_real_name, normalized_month_text)
        self._date_picker_click_delegate(month_delegates, normalized_month_text, "month")

    def date_picker_click_year_by_text(self, years_real_name: dict, year_text: str):
        year_delegates = self.date_picker_get_items_by_text(years_real_name, year_text)
        self._date_picker_click_delegate(year_delegates, year_text, "year")

    def find_child_by_type(self, parent, child_type, max_depth=5):
        """
        Find the first child of a given type within an object.

        Args:
            parent: The parent Squish object.
            child_type: The type name to search for. This generally refers to QML types like "QQuickText", "QQuickRectangle", etc.
            max_depth: Maximum recursion depth.

        Returns:
            The first matching child object, or None.
        """
        if max_depth <= 0:
            return None

        try:
            children = squishtest.object.children(parent)
        except Exception:
            return None

        for child in children:
            if squishtest.className(child) == child_type:
                return child

            result = self.find_child_by_type(child, child_type, max_depth - 1)
            if result is not None:
                return result

        return None

    def find_children_by_type(self, parent, child_type, max_depth=5):
        """
        Find all children of a given type within an object.

        Args:
            parent: The parent Squish object.
            child_type: The type name to search for.
            max_depth: Maximum recursion depth.

        Returns:
            List of matching child objects.
        """
        results = []
        self._collect_children_by_type(parent, child_type, results, max_depth)
        return results

    def _collect_children_by_type(self, parent, child_type, results, max_depth):
        """Recursive helper for find_children_by_type."""
        if max_depth <= 0:
            return

        try:
            children = squishtest.object.children(parent)
        except Exception:
            return

        for child in children:
            if squishtest.className(child) == child_type:
                results.append(child)
            self._collect_children_by_type(child, child_type, results, max_depth - 1)

    def find_child_by_property(self, parent, child_type: str, property_name: str, property_value, max_depth=5):
        """
        Find a child of a given type where a specific property
        matches a given value.

        Args:
            parent: The parent Squish object.
            child_type: The type name to search for. This generally refers to QML types like "QQuickText", "QQuickRectangle", etc.
            property_name: The property to match on.
            property_value: The expected value (compared as strings).
            max_depth: Maximum recursion depth.

        Returns:
            The first matching child object, or None.
        """
        candidates = self.find_children_by_type(parent, child_type, max_depth)

        for child in candidates:
            try:
                value = str(getattr(child, property_name))
                if value == str(property_value):
                    return child
            except (AttributeError, RuntimeError):
                continue

        return None

    def capture_and_return_base64_image(self, g4_app_real_name, filename: str = None, caption: str = None, output_dir: str = None) -> str:
        import squishtest as squish
        import datetime
        import os
        import base64
        try:
            root = squish.waitForObjectExists(g4_app_real_name)
        except Exception as e:
            raise RuntimeError(f"Could not resolve or locate '{g4_app_real_name}': {e}")

        try:
            img = squish.object.grabScreenshot(root, {"delay": 0})
        except Exception as _grab_err:
            print(f"*WARN* Screenshot capture skipped: grabScreenshot raised {type(_grab_err).__name__}: {_grab_err}")
            return ""

        if img is None:
            print("*WARN* Screenshot capture skipped: grabScreenshot returned no data.")
            return ""

        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        if not filename:
            filename = f"screenshot_{timestamp}.png"

        reports_dir = output_dir or os.environ.get("SQUISH_REPORTS_DIR", os.getcwd())
        image_path = os.path.join(reports_dir, filename)

        # Save the file (for record-keeping, even if not used in log)
        img.save(image_path)

        # Read and encode the image in base64
        with open(image_path, "rb") as img_file:
            encoded = base64.b64encode(img_file.read()).decode("utf-8")

        # Return encoded <img> tag
        return f'<img src="data:image/png;base64,{encoded}" width="800px"/>'

    def drag_object_by_offset(self, object_real_name: dict, direction: str, distance: int, **kwargs):
        """
        Drags object on screen using globalBounds + ScreenPoint.
        direction: 'up' | 'down' | 'left' | 'right'
        distance : pixels (positive int)
        Optional kwargs:
          - start_x, start_y : override start point (screen coords)
          - button, modifier, steps, delay_ms
        """
        # Normalize inputs
        direction = str(direction).lower().strip()
        distance = int(distance)
        # Validate distance
        if distance < 0:
            raise ValueError("distance must be >= 0 (use direction to control sign)")
        # Convert direction+distance -> dx/dy
        dx, dy = 0, 0
        if direction == "down":
            dy = distance
        elif direction == "up":
            dy = -distance
        elif direction == "right":
            dx = distance
        elif direction == "left":
            dx = -distance
        else:
            raise ValueError("direction must be one of: up, down, left, right")
        # Resolve object reference
        obj = self.get_object_reference(object_real_name, True)
        # Get GLOBAL bounds
        rect = self.get_object_global_bounds(obj)  # ScreenRectangle
        # Compute start point (default center)
        margin = int(kwargs.get("margin", 2))
        # start point default = center (clamped a bit away from edges)
        start_x = kwargs.get("start_x", rect.x + rect.width // 2)
        start_y = kwargs.get("start_y", rect.y + rect.height // 2)
        # Compute end point
        end_x = start_x + dx
        end_y = start_y + dy
        # Read mouse/gesture params
        button = int(kwargs.get("button", 1))
        modifier = int(kwargs.get("modifier", 0))
        steps = int(kwargs.get("steps", 30))
        delay_ms = int(kwargs.get("delay_ms", 10))
        # Convert to ScreenPoint
        sp_start = squishtest.UiTypes.ScreenPoint(start_x, start_y)
        sp_end = squishtest.UiTypes.ScreenPoint(end_x, end_y)
        # Perform drag
        squishtest.mouseMove(sp_start)
        squishtest.mousePress(sp_start, button, modifier)
        for i in range(1, steps + 1):
            x = int(start_x + (end_x - start_x) * i / steps)
            y = int(start_y + (end_y - start_y) * i / steps)
            squishtest.mouseMove(squishtest.UiTypes.ScreenPoint(x, y))
            if delay_ms:
                squishtest.snooze(delay_ms / 500.0)
        squishtest.mouseRelease(sp_end, button, modifier)
        # Return log
        return (
            f"Drag OK | dir={direction}, dist={distance}, "
            f"start=({start_x},{start_y}), end=({end_x},{end_y}), "
            f"rect=({rect.x},{rect.y},{rect.width},{rect.height})"
        )

    def find_all_objects(self, object_real_name: dict) -> list:
        """Returns a list of all objects matching `object_real_name` using findAllObjects.

        Args:
            object_real_name: Object real name dictionary (may use RegularExpression for objectName).

        Returns:
            List of all matching object references.
        """
        return list(squishtest.findAllObjects(object_real_name))

    def _get_delegate_at_index(self, delegates: list, index: int, delegate_label: str):
        """
        Shared logic for retrieving a delegate at a specific index from a pre-fetched list.
        Validates bounds and returns the delegate reference.

        Args:
            delegates: List of delegate objects (pre-fetched via find_all_objects).
            index: The index of the delegate to retrieve.
            delegate_label: Label used in error messages (e.g. 'report row', 'view button').

        Returns:
            The delegate object at the given index.
        """
        index = int(index)
        if not delegates:
            raise RuntimeError(f"No {delegate_label} delegates found.")
        if index < 0 or index >= len(delegates):
            raise IndexError(
                f"Index {index} out of bounds for {delegate_label}. Found {len(delegates)} delegate(s)."
            )
        return delegates[index]

    def get_property_of_nth_object(self, object_real_name: dict, index: int, property_path: str) \
            -> Union[str, bool, int, float, dict, None]:
        """Finds all objects matching `object_real_name`, picks the one at `index`,
        and returns the value of `property_path`.

        This is essential for iterating through repeated UI elements (e.g., list rows)
        where waitForObject always returns the first match.

        Args:
            object_real_name: Object real name dictionary (may use RegularExpression for objectName).
            index: Zero-based index of the target object among all matches.
            property_path: Dot-separated property path (e.g. 'font.family', 'color.name').

        Returns:
            The property value, or None if property does not exist.
        """
        delegates = self.find_all_objects(object_real_name)
        delegate = self._get_delegate_at_index(delegates, index, "object")

        try:
            prop = self._get_nested_property(delegate, property_path)
        except AttributeError as e:
            print(f"*ERROR* Object at index {index} does not contain {property_path=}. Original error: {e}")
            return None

        prop_type = squishtest.className(prop)
        if prop_type == 'QString':
            return str(prop)
        elif prop_type in ('bool', 'int', 'float'):
            return prop
        else:
            return self._get_object_properties(prop)

    def click_nth_object(self, object_real_name: dict, index: int):
        """Finds all objects matching `object_real_name`, picks the one at `index`, and clicks it.

        This is essential for iterating through repeated UI elements (e.g., list row buttons)
        where waitForObject always returns the first match.

        Args:
            object_real_name: Object real name dictionary (may use RegularExpression for objectName).
            index: Zero-based index of the target object among all matches.
        """
        delegates = self.find_all_objects(object_real_name)
        delegate = self._get_delegate_at_index(delegates, index, "object")

        self.mouse_click_object_reference(delegate, int(delegate.width) // 2, int(delegate.height) // 2)

# Execute this on module level, because it must
# be executed only once:
squishtest.testSettings.logScreenshotOnFail = True
squishtest.setTestResult("xml3.4", "%s/test_results_xml" % os.environ[SQUISH_REPORTS_DIR_ENV_NAME])
