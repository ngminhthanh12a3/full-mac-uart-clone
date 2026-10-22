IP?=172.21.162.155

test:
	python keithley_full.py --ip ${IP} \
	--voltages 0.9 1.0 1.1 \
	--max-voltage 1.1 \
	--current-limit 0.02 \
	--run
sweep:
	python keithley_full.py --ip ${IP} \
	--voltages 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 \
	--max-voltage  2.0 \
	--current-limit 0.1 \
	--settle 0.1 \
	--samples 10 \
	--nplc 1 \
	--run