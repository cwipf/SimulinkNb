classdef FlexTF < realp
    %FlexTF  Container for frequency response data in Simulink
    %   How to use this feature:
    %
    %   1. Construct a FlexTF with frequency response data for a Simulink
    %   block (see "help frd" for more on how to store this data).
    %   >> flextf_block = FlexTF(frd(response, freqs, 'Units', 'Hz'));
    %
    %   2. Attach a FlexTF to a Simulink block.  To do this, right-click
    %   the block, and choose "Linear Analysis > Specify Selected Block
    %   Linearization".  The Block Linearization Specification dialog box
    %   will open.  Enable "Specify block linearization using... MATLAB
    %   Expression", then enter the expression for the FlexTF.
    %
    %   3. Linearizing a Simulink model containing a FlexTF returns a
    %   generalized state space (genss) model.  Use FlexTF.replaceBlocks to
    %   insert block-level frequency response data into the genss model.
    %   >> sys = linearize(model);
    %   >> sys = FlexTF.replaceBlocks(sys);
    %
    %   4. Use FlexTF.prescale before calling FlexTF.replaceBlocks, if
    %   needed to improve accuracy in a target frequency range.
    %   >> sys = FlexTF.prescale(sys, {min_freq, max_freq});
    %
    %   See also REALP, GENSS, REPLACEBLOCKS, PRESCALE.

    properties
        FRData;
    end

    methods
        function blk = FlexTF(varargin)
            name = [];
            value = [];
            frdata = [];
            switch nargin
                case 1
                    % One argument: FRD
                    % Give the FlexTF a random unique name
                    % Give it a value that connects all I/Os and matches
                    % the dimensions of the FRD
                    frdata = varargin{1};
                    value = ones(size(frdata));
                    name = ['frd_' strrep(char(java.util.UUID.randomUUID),'-','_')];
                case 2
                    % Two arguments: like realp; FRD left empty
                    name = varargin{1};
                    value = varargin{2};
                case 3
                    % Three arguments: fully specified FlexTF
                    name = varargin{1};
                    value = varargin{2};
                    frdata = varargin{3};
            end
            blk@realp(name, value);
            blk.FRData = frdata;
        end
        
        function disp(blk)
            s = struct;
            s.FRData = blk.FRData;
            fprintf(' %s\n',deblank(evalc('disp(s)')))
            disp(realp(blk.Name, blk.Value));
        end
    end

    methods (Static = true)
        function out = replaceBlocks(in)
            % replaceBlocks  Insert frequency response data from FlexTF blocks
            % See also InputOutputModel/replaceBlock.
            if ~isprop(in, 'Blocks')
                % not a genss model: just pass it through
                out = in;
                return;
            end
            % genss model: assemble blockvalues struct with all the FlexTFs
            blocks = fieldnames(in.Blocks);
            blockvalues = struct;
            for n = 1:numel(blocks)
                block = in.Blocks.(blocks{n});
                if isprop(block, 'FRData') % make sure it's a FlexTF block
                    blockvalues.(blocks{n}) = block.FRData;
                end
            end
            % insert FlexTFs
            out = replaceBlock(in, blockvalues);
        end
        
        function scaledsys = prescale(sys, focus)
            % PRESCALE  Optimally scale the state-space part of a genss model
            % See also ss/prescale.
            if ~isprop(sys, 'Blocks')
                % not a genss model: use the standard prescale function
                scaledsys = prescale(sys, focus);
                return;
            end
            % genss model: unpack, prescale the ss part, repack
            [H, B, S] = getLFTModel(sys);
            H = prescale(H, focus);
            scaledsys = lft(H,blkdiag(B{:})-S);
        end
    end

end