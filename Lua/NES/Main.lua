require "Constants"
require "Inputs"
require "NeuralNetwork"
require "Pools"
require "SaveStates"
require "Forms"
require "Timeout"
require "SQL"


function InitializeStats()
	local statsFile=io.open("Stats.csv","w+")
	statsFile:write("Generation".. ","  .. "Max Fitness".. "," .. "Average Fitness" .. "," .. "World" .. "," .. "Level" .. "\n")
	statsFile:close()
end


function CollectStats()
	local statsFile=io.open("Stats.csv","a")
	statsFile:write(pool.generation .. ","  .. pool.maxFitness .. "," .. pool.generationAverageFitness .. "," .. pool.marioWorld .. "," .. pool.marioLevel .. "\n")
	statsFile:close()
end	

function FileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end


function GatherReward(probalisticGenome,probalisticSpecies)
	isDone=nextGenome(probalisticGenome,probalisticSpecies)
	if isDone ==1 then 
		mode=DEATH_ACTION
		GenomeAmount=0
	elseif isDone==2 then
		CollectStats()
		console.writeline("Generation " .. pool.generation .. " Completed")
		console.writeline("For World ".. pool.marioWorld+1 .. " Level ".. pool.marioLevel+1)
		console.writeline("Generation Best Fitness: ".. pool.maxGenerationFitness  .." Max Fitness: ".. pool.maxFitness)
		pool.maxGenerationFitness=0
		mode=GENERATION_OVER
		GenomeAmount=0	
	else
		GenomeAmount=GenomeAmount+1
		initializeRun()
		fitness=GeneticAlgorithmLoop(probalisticGenome)
		UpdateReward(fitness)
		mode=WAIT
		DummyRow()
		status=0
	end
end

function GeneticAlgorithmLoop(probalisticGenome)
	local Alive=true
	local GlobalFitness=0
	

	while Alive do

		local species = pool.species[pool.currentSpecies]
		local genome = species.genomes[pool.currentGenome]
        if FileExists("display.txt") then
			displayGenome(genome)
		end
		--Every 5 frames evaluate the current orgranism
		if pool.currentFrame%5 == 0 then
				evaluateCurrent()
		end

		--Sets the output to whatever the netowrk chooses
		joypad.set(controller)

		--Get Postion of Mario reading the Hex Bits
		getPositions()

		--Refeshes Timeout
		if pool.currentFrame%4 == 0 then
			CallTimeoutFunctions()
		end



		--Subtract one time unit each loop
		timeout = timeout - 1

		--Each extra four frames give mario and extra bonus living amount
		local timeoutBonus = pool.currentFrame / 4
		--Timeout or Killed by Monster or Kiled by Falling
		if timeout + timeoutBonus <=0 or memory.readbyte(0x000E)==11 or memory.readbyte(0x00B5)>1 then
			Alive=false
			--If Dead
			

			local fitness = 0
			local fitnesscheck={}
			for slot=1,5 do
				fitnesscheck[slot]=0
			end
			genome.ran=true
			if forms.ischecked(RightmostFitness) then
				fitnesscheck[1] = tonumber(forms.gettext(RightmostAmount))*(rightmost - NetX)
				genome.rightmostFitness=fitnesscheck[1]
				if marioX> pool.maxFitness then
					pool.maxFitness=marioX
				end
				if marioX> pool.maxGenerationFitness then
					pool.maxGenerationFitness=marioX
				end
			end
			if forms.ischecked(ScoreFitness) then
				fitnesscheck[2] = fitness+tonumber(forms.gettext(ScoreAmount))*(marioScore - NetScore)
			end
			if forms.ischecked(NoveltyFitness) then
				fitnesscheck[3] = fitness +tonumber(forms.gettext(NoveltyAmount))*(CurrentNSFitness)
			end
			-- if (rightmost-NetX)>20 then
			-- 	fitnesscheck[4] = (NetX-leftmost)*2+(rightmost-NetX)*.5
			-- end
			-- if (rightmost-NetX)>20 then
			-- 	fitnesscheck[5] = (upmost - NetY)*3+(rightmost-NetX)*.25
			-- end

			table.sort(fitnesscheck)
			fitness=fitnesscheck[#fitnesscheck]


			if fitness == 0 then
				fitness = -1
			end


			--New Code for Super Meta
			if memory.readbyte(0x000E)==11 or memory.readbyte(0x00B5)>1 then
				fitness= fitness-20
				status=1
				savestate.load(Filename)
			end
			LevelChange()
			LevelChangeHalfway()
			
			



			if fitness > genome.fitness then
				genome.fitness = fitness
			end


			if fitness <= 0 then
				GlobalFitness=-1
			elseif fitness>500 then 
				GlobalFitness=1
			else 
				GlobalFitness=fitness/500
			end
			


		end

		pool.currentFrame = pool.currentFrame + 1
		emu.frameadvance()
	end	
	return GlobalFitness
end


DEATH_WAIT,DEATH_ACTION,WAIT,ACTION,GENERATION_OVER = 0,1,2,3,4
mode=WAIT



Open()
savestate.load(Filename) --load Level 1
FitnessBox(140,40,600,700) --Set Dimensions of GUI



GenomeAmount=0
status=0

initializePool()
load=false
if FileExists("current.pool") then
	loadFile("current.pool")
	load=true
	console.writeline("Model Loaded")
	savestate.load(Filename)
else
	InitializeStats()
end
UpdateGenes(CollectGenes())
if load==false then
	DummyRow()
else
	DummyRowLoad()
end
while true do
	if (mode~=DEATH_ACTION) and memory.readbyte(0x000E)==11 then    
	   --mode=DEATH_WAIT 
	end
	if mode==DEATH_ACTION then
		DummyRowDead()
		savestate.load(Filename)
		mode=WAIT
	end 
	if mode==GENERATION_OVER then
		DummyRowEnd()
		savestate.load(Filename)
		mode=WAIT
	end 
	if mode==DEATH_WAIT and emu.checktable()==false then
		EraseLastAction()
		DummyRowDead()
		savestate.load(Filename)
		mode=WAIT
	end 
    if mode==WAIT and emu.checktable()==false then
 		mode=ACTION
 	end
 	if mode==ACTION then
 		local probalisticGenome=GatherGenomeNum() --Fix Functi
 		local probalisticSpecies=GatherSpeciesNum() --Fix Function
 		GatherReward(probalisticGenome,probalisticSpecies)
 	end	
 	emu.frameadvance()

end