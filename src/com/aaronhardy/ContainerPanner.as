// Copyright (c) 2010 Aaron Hardy
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

package com.aaronhardy
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	
	import mx.core.Container;
	import mx.events.FlexEvent;
	import mx.managers.CursorManager;
	import mx.managers.CursorManagerPriority;
	
	/**
	 * Allows a container to be panned using the cursor without using the scrollbars.  When panning 
	 * is turned on, no mouse events will reach the contents of the container.  Scrollbars remain 
	 * active. If preferred, custom mouse cursors may be used.
	 */
	public class ContainerPanner
	{
		private var _upCursor:Class;
		
		/**
		 * The class to use for the cursor when panning is enabled and the cursor is over the
		 * container but not actively panning.
		 */
		public function get upCursor():Class
		{
			return _upCursor;
		}
		
		/**
		 * @private
		 */
		public function set upCursor(value:Class):void
		{
			if (_upCursor != value)
			{
				_upCursor = value;
				_upCursorDimensions = null;
			}
		}
		
		protected var _upCursorDimensions:Rectangle;
		
		/**
		 * @private
		 * The dimensions of the upCursor.
		 */
		protected function get upCursorDimensions():Rectangle
		{
			if (!_upCursorDimensions && upCursor)
			{
				var cursor:DisplayObject = new upCursor();
				_upCursorDimensions = new Rectangle(0, 0, cursor.width, cursor.height);
			}
			return _upCursorDimensions;
		}
		
		//-----------------------------------------------------------------------------------
		
		private var _downCursor:Class;
		
		/**
		 * The class to use for the cursor when panning is enabled and the cursor is over the
		 * container and actively panning.
		 */
		public function get downCursor():Class
		{
			return _downCursor;
		}
		
		/**
		 * @private
		 */
		public function set downCursor(value:Class):void
		{
			if (_downCursor != value)
			{
				_downCursor = value;
				_downCursorDimensions = null;
			}
		}
		
		protected var _downCursorDimensions:Rectangle;
		
		/**
		 * @private
		 * The dimensions of the downCursor.
		 */
		protected function get downCursorDimensions():Rectangle
		{
			if (!_downCursorDimensions && downCursor)
			{
				var cursor:DisplayObject = new downCursor();
				_downCursorDimensions = new Rectangle(0, 0, cursor.width, cursor.height);
			}
			return _downCursorDimensions;
		}
		
		//-----------------------------------------------------------------------------------
		
		private var _container:Container;
		
		/**
		 * The container that should be panned when appropriate mouse events occur.
		 */
		public function get container():Container
		{
			return _container;
		}		
		
		/**
		 * @private
		 */
		public function set container(value:Container):void
		{
			if (_container != value)
			{
				// We must deconstruct beforehand if needed so we can remove listeners.
				if (container && panningConstructed)
				{
					deconstructPanning();
				}
				
				_container = value;
				updatePanningConstruction();
			}
		}
		
		//-----------------------------------------------------------------------------------
		
		private var _panEnabled:Boolean = true;
		
		/**
		 * Whether panning is enabled.  When this is false, this class doesn't really provide
		 * any functionality.  But it's more convenient than destroying and recreating the class
		 * to toggle panning functionality.
		 */
		public function get panEnabled():Boolean
		{
			return _panEnabled;
		}
		
		/**
		 * @private
		 */
		public function set panEnabled(value:Boolean):void
		{
			if (_panEnabled != value)
			{
				_panEnabled = value;
				updatePanningConstruction();
			}
		}
		
		//////////////////////////////////////////////////////////////
		// Panning setup
		//////////////////////////////////////////////////////////////
		
		protected var panningConstructed:Boolean = false;
		
		protected function updatePanningConstruction():void
		{
			if (container && panEnabled)
			{
				if (!panningConstructed)
				{
					constructPanning();
				}
			}
			else
			{
				if (panningConstructed)
				{
					deconstructPanning();
				}
			}
		}
		
		protected function constructPanning():void
		{
			if (!hitArea)
			{
				// Must be an interactive object so it can catch mouse events.
				hitArea = new Sprite();
			}
			
			container.addEventListener(FlexEvent.UPDATE_COMPLETE, updateHitAreaSize);
			container.rawChildren.addChild(hitArea);
			updateHitAreaSize();
			
			// If the cursor is already over the hit area, set the custom cursor now.
			if (container.stage && 
					hitArea.hitTestPoint(container.stage.mouseX, container.stage.mouseY))
			{
				setUpCursor();
			}
			
			// Watching for roll outs to remove the custom cursor.
			hitArea.addEventListener(MouseEvent.ROLL_OUT, removeUpCursor);
			// If the user rolls over the hit area, set the custom cursor.
			hitArea.addEventListener(MouseEvent.ROLL_OVER, setUpCursor);
			// Watching for mouse downs because that's when we start panning.
			hitArea.addEventListener(MouseEvent.MOUSE_DOWN, hitArea_mouseDownHandler);
			panningConstructed = true;
		}
		
		protected function deconstructPanning():void
		{
			container.removeEventListener(FlexEvent.UPDATE_COMPLETE, updateHitAreaSize);
			hitArea.removeEventListener(MouseEvent.ROLL_OUT, removeUpCursor);
			hitArea.removeEventListener(MouseEvent.ROLL_OVER, setUpCursor);
			hitArea.removeEventListener(MouseEvent.MOUSE_DOWN, hitArea_mouseDownHandler);
			container.rawChildren.removeChild(hitArea);
			panningConstructed = false;
		}
		
		protected function updateHitAreaSize(event:Event=null):void
		{
			// Figure out the size of the container without the scrollbars.
			// As it is, we're SOL if the container changes size while we're rolled over,
			// but it wouldn't be hard to update the hit area on container size changes.
			var hitAreaWidth:Number = container.width;
			
			if (container.verticalScrollBar)
			{
				hitAreaWidth -= container.verticalScrollBar.width;
			}
			
			var hitAreaHeight:Number = container.height;
			
			if (container.horizontalScrollBar)
			{
				hitAreaHeight -= container.horizontalScrollBar.height;
			}
			
			// Create the hit area sprite, add it as a raw child (so it's not within the content
			// pane)
			hitArea.graphics.clear();
			hitArea.graphics.beginFill(0xffffff, 0);
			hitArea.graphics.drawRect(0, 0, hitAreaWidth, hitAreaHeight);
			hitArea.graphics.endFill();
		}
		
		/**
		 * This is a sprite to catch relevant events occurring over all the container except for
		 * the scroll bars.  When the user is over the scrollbars, we don't want any panning
		 * functionality going on.
		 */
		protected var hitArea:Sprite;
		
		/**
		 * The ID of the up cursor.
		 */
		protected var upCursorId:int = 0;
		
		/**
		 * Sets the up cursor if it hasn't already been set.
		 */
		protected function setUpCursor(event:Event=null):void
		{
			if (upCursorId == 0 && upCursor)
			{
				upCursorId = CursorManager.setCursor(upCursor, CursorManagerPriority.MEDIUM,
						-upCursorDimensions.width / 2, -upCursorDimensions.height / 2);
			}
		}
		
		/**
		 * Reverts the up cursor if it hasn't been reverted already.
		 */
		protected function removeUpCursor(event:Event):void
		{
			// While we could have used CursorManager.currentCursorID, we want to be conscious
			// of the possibility that a different cursor may have been set externally in the
			// interim.  We'll use the stored cursor ID specific to our hand cursor just in case.
			if (upCursorId > 0)
			{
				CursorManager.removeCursor(upCursorId);
				upCursorId = 0;
			}
		}
		
		/**
		 * The ID of the down cursor.
		 */
		protected var downCursorId:int = 0;
		
		/**
		 * Sets the down cursor if it hasn't already been set.
		 */
		protected function setDownCursor(event:Event=null):void
		{
			if (downCursorId == 0 && downCursor)
			{
				var cursor:DisplayObject = new downCursor();
				downCursorId = CursorManager.setCursor(downCursor, CursorManagerPriority.HIGH,
						-downCursorDimensions.width / 2, -downCursorDimensions.height / 2);
			}
		}
		
		/**
		 * Reverts the down cursor if it hasn't been reverted already.
		 */
		protected function removeDownCursor(event:Event=null):void
		{
			// While we could have used CursorManager.currentCursorID, we want to be conscious
			// of the possibility that a different cursor may have been set externally in the
			// interim.  We'll use the stored cursor ID specific to our hand cursor just in case.
			if (downCursorId > 0)
			{
				CursorManager.removeCursor(downCursorId);
				downCursorId = 0;
			}
		}
		
		//////////////////////////////////////////////////////////////
		// Panning execution
		//////////////////////////////////////////////////////////////
		
		/**
		 * The stage X of the cursor the last time it was captured (last move/mouse down event).
		 * Used to track the delta as the user drags.
		 */
		protected var previousStageX:Number;
		
		/**
		 * The stage Y of the cursor the last time it was captured (last move/mouse down event).
		 * Used to track the delta as the user drags.
		 */
		protected var previousStageY:Number;
		
		protected var mouseBoundsMinX:Number;
		protected var mouseBoundsMaxX:Number;
		protected var mouseBoundsMinY:Number;
		protected var mouseBoundsMaxY:Number;
				
		/**
		 * Handles when the user mouses down on the container.
		 */
		protected function hitArea_mouseDownHandler(event:MouseEvent):void
		{
			container.stage.addEventListener(MouseEvent.MOUSE_MOVE, stage_mouseDownAndMoveHandler, true);
			container.stage.addEventListener(MouseEvent.MOUSE_UP, stage_mouseUpHandler, true);
			container.stage.addEventListener(Event.MOUSE_LEAVE, stage_mouseUpHandler);
			previousStageX = event.stageX;
			previousStageY = event.stageY;
			
			// Store the effective bounds of the mouse.  Take this scenario: the user mouses
			// down and drags to the right and the container hits its max scroll position when the 
			// mouse is at stageX = 1000.  The user continues dragging to stageX = 1200 but the 
			// container doesn't scroll any farther because it hit its max when the cursor was at 
			// 1000. If the user continues dragging but moves in the opposite direction, we don't 
			// want to reverse the container's scrolling until the cursor hits stageX=1000 and 
			// continues moving left.  By storing the corners of "effective mouse bounds", we can
			// handle this fairly simply.
			// Note that this is one of the more efficient ways of handling this problem, but it
			// doesn't accommodate a container that's resizing while being panned or who's contents
			// are resizing while being panned.
			mouseBoundsMinX = event.stageX - 
					(container.maxHorizontalScrollPosition - container.horizontalScrollPosition);
			mouseBoundsMaxX = event.stageX + container.horizontalScrollPosition;
			mouseBoundsMinY = event.stageY - 
					(container.maxVerticalScrollPosition - container.verticalScrollPosition);
			mouseBoundsMaxY = event.stageY + container.verticalScrollPosition;
			setDownCursor();
		}
		
		/**
		 * Handles when the user has moused down and is moving the cursor on the stage (dragging).
		 */
		protected function stage_mouseDownAndMoveHandler(event:MouseEvent):void
		{
			// Clamp the mouse position to effective mouse bounds.
			// See hitArea_mouseDownHandler for more info.
			var stageX:Number = clamp(event.stageX, mouseBoundsMinX, mouseBoundsMaxX);
			var stageY:Number = clamp(event.stageY, mouseBoundsMinY, mouseBoundsMaxY);
			
			var deltaX:Number = stageX - previousStageX;
			var deltaY:Number = stageY - previousStageY;
			container.horizontalScrollPosition -= deltaX;
			container.verticalScrollPosition -= deltaY;
			previousStageX = stageX;
			previousStageY = stageY;
		}
		
		/**
		 * Clamp a number to within a range.
		 * @param value The value to clamp.
		 * @param min The minimum clamp range.
		 * @param max The maximum clamp range.
		 */
		protected function clamp(value:Number, min:Number, max:Number):Number
		{
			return Math.min(Math.max(value, min), max);
		}
		
		/**
		 * Handles when the user mouses up.
		 */
		protected function stage_mouseUpHandler(event:Event):void
		{
			removeDownCursor();
			removeStageListeners();
		}
		
		/**
		 * Removes stage listeners.
		 */
		protected function removeStageListeners():void
		{
			container.stage.removeEventListener(MouseEvent.MOUSE_MOVE, stage_mouseDownAndMoveHandler, true);
			container.stage.removeEventListener(MouseEvent.MOUSE_UP, stage_mouseUpHandler, true);
			container.stage.removeEventListener(Event.MOUSE_LEAVE, stage_mouseUpHandler);
		}
	}
}