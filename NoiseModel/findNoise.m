% Extracts a Noise or NoiseModel from within another NoiseModel.
% If nothing is found, 0 is returned.
%
% Sean Leavey
function foundModel = findNoise(name, model)
    if isa(model, 'NoiseModel')
        if strcmp(name, model.title)
            foundModel = model;

            return
        else
            for thisModel = model.modelNoises
                thisModel = thisModel{:};

                thisFoundModel = findNoise(name, thisModel);

                if isa(thisFoundModel, 'NoiseModel') || isa(thisFoundModel, 'Noise')
                    foundModel = thisFoundModel;

                    return;
                end
            end
        end
    elseif isa(model, 'Noise')
        if strcmp(name, model.name)
            foundModel = model;

            return;
        end
    end

    foundModel = 0;
end