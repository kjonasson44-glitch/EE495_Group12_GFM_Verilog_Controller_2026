	component issp_control is
		port (
			probe      : in  std_logic_vector(63 downto 0) := (others => 'X'); -- probe
			source_clk : in  std_logic                     := 'X';             -- clk
			source     : out std_logic_vector(99 downto 0)                     -- source
		);
	end component issp_control;

	u0 : component issp_control
		port map (
			probe      => CONNECTED_TO_probe,      --     probes.probe
			source_clk => CONNECTED_TO_source_clk, -- source_clk.clk
			source     => CONNECTED_TO_source      --    sources.source
		);

