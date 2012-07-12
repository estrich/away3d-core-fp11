package away3d.animators
{
	import away3d.animators.*;
	import away3d.animators.data.*;
	import away3d.core.managers.*;
	import away3d.materials.passes.*;

	/**
	 * The animation data set used by vertex-based animators, containing vertex animation state data.
	 * 
	 * @see away3d.animators.VertexAnimator
	 * @see away3d.animators.VertexAnimationState
	 */
	public class VertexAnimationSet extends AnimationSetBase implements IAnimationSet
	{
				
		private var _numPoses : uint;
		private var _blendMode : String;
		private var _streamIndex : uint;
		private var _useNormals : Boolean;
		private var _useTangents : Boolean;
		
		/**
		 * Returns the number of poses made available at once to the GPU animation code.
		 */
		public function get numPoses() : uint
		{
			return _numPoses;
		}
		
		/**
		 * Returns the active blend mode of the vertex animator object.
		 */
		public function get blendMode() : String
		{
			return _blendMode;
		}
		
		/**
		 * Returns the set stream index for the animation component of the GPU vertex shader.
		 */
		public function get streamIndex() : uint
		{
			return _streamIndex;
		}
		
		/**
		 * Returns whether or not normal data is used in last set GPU pass of the vertex shader. 
		 */
		public function get useNormals() : Boolean
		{
			return _useNormals;
		}
		
		/**
		 * Creates a new <code>VertexAnimationSet</code> object.
		 * 
		 * @param numPoses The number of poses made available at once to the GPU animation code.
		 * @param blendMode Optional value for setting the animation mode of the vertex animator object.
		 * 
		 * @see away3d.animators.data.VertexAnimationMode
		 */
		public function VertexAnimationSet(numPoses : uint = 2, blendMode : String = "absolute" )
		{
			super();
			_numPoses = numPoses;
			_blendMode = blendMode;
			
		}
		
		/**
		 * @inheritDoc
		 */
		public function getAGALVertexCode(pass : MaterialPassBase, sourceRegisters : Array, targetRegisters : Array) : String
		{
			if (_blendMode == VertexAnimationMode.ABSOLUTE)
				return getAbsoluteAGALCode(pass, sourceRegisters, targetRegisters);
			else
				return getAdditiveAGALCode(pass, sourceRegisters, targetRegisters);
		}
		
		
		/**
		 * @inheritDoc
		 */
		public function activate(stage3DProxy : Stage3DProxy, pass : MaterialPassBase) : void
		{
		}
		
		/**
		 * @inheritDoc
		 */
		public function deactivate(stage3DProxy : Stage3DProxy, pass : MaterialPassBase) : void
		{
			stage3DProxy.setSimpleVertexBuffer(_streamIndex, null, null, 0);
			if (_useNormals)
				stage3DProxy.setSimpleVertexBuffer(_streamIndex + 1, null, null, 0);
			if (_useTangents)
				stage3DProxy.setSimpleVertexBuffer(_streamIndex + 2, null, null, 0);
		}
		
		/**
		 * @inheritDoc
		 */
		public override function addState(stateName:String, animationState:IAnimationState):void
		{
			super.addState(stateName, animationState);
			
			animationState.addOwner(this, stateName);
		}
		
		/**
		 * Generates the vertex AGAL code for absolute blending.
		 */
		private function getAbsoluteAGALCode(pass : MaterialPassBase, sourceRegisters : Array, targetRegisters : Array) : String
		{
			var code : String = "";
			var temp1 : String = findTempReg(targetRegisters);
			var temp2 : String = findTempReg(targetRegisters, temp1);
			var regs : Array = ["x", "y", "z", "w"];
			var len : uint = sourceRegisters.length;
			_useNormals = len > 1;
			_useTangents = len > 2;
			if (len > 2) len = 2;
			_streamIndex = pass.numUsedStreams;

			var k : uint;
			for (var i : uint = 0; i < len; ++i) {
				for (var j : uint = 0; j < _numPoses; ++j) {
					if (j == 0) {
						code += "mul " + temp1 + ", " + sourceRegisters[i] + ", vc" + pass.numUsedVertexConstants + "." + regs[j] + "\n";
					}
					else {
						code += "mul " + temp2 + ", va" + (_streamIndex + k) + ", vc" + pass.numUsedVertexConstants + "." + regs[j] + "\n";
						if (j < _numPoses - 1) code += "add " + temp1 + ", " + temp1 + ", " + temp2 + "\n";
						else code += "add " + targetRegisters[i] + ", " + temp1 + ", " + temp2 + "\n";
						++k;
					}
				}
			}

			if (_useTangents) {
				code += "dp3 " + temp1 + ".x, " + sourceRegisters[uint(2)] + ", " + targetRegisters[uint(1)] + "\n" +
						"mul " + temp1 + ", " + targetRegisters[uint(1)] + ", " + temp1 + ".x			 \n" +
						"sub " + targetRegisters[uint(2)] + ", " + sourceRegisters[uint(2)] + ", " + temp1 + "\n";
			}
			return code;
		}
		
		/**
		 * Generates the vertex AGAL code for additive blending.
		 */
		private function getAdditiveAGALCode(pass : MaterialPassBase, sourceRegisters : Array, targetRegisters : Array) : String
		{
			var code : String = "";
			var len : uint = sourceRegisters.length;
			var regs : Array = ["x", "y", "z", "w"];
			var temp1 : String = findTempReg(targetRegisters);
			var k : uint;

			_useNormals = len > 1;
			_useTangents = len > 2;

			if (len > 2) len = 2;

			code += "mov  " + targetRegisters[0] + ", " + sourceRegisters[0] + "\n";
			if (_useNormals) code += "mov " + targetRegisters[1] + ", " + sourceRegisters[1] + "\n";

			for (var i : uint = 0; i < len; ++i) {
				for (var j : uint = 0; j < _numPoses; ++j) {
					code += "mul " + temp1 + ", va" + (_streamIndex + k) + ", vc" + pass.numUsedVertexConstants + "." + regs[j] + "\n" +
							"add " + targetRegisters[i] + ", " + targetRegisters[i] + ", " + temp1 + "\n";
					k++;
				}
			}

			if (_useTangents) {
				code += "dp3 " + temp1 + ".x, " + sourceRegisters[uint(2)] + ", " + targetRegisters[uint(1)] + "\n" +
						"mul " + temp1 + ", " + targetRegisters[uint(1)] + ", " + temp1 + ".x			 \n" +
						"sub " + targetRegisters[uint(2)] + ", " + sourceRegisters[uint(2)] + ", " + temp1 + "\n";
			}

			return code;
		}
	}
}
