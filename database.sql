-- --------------------------------------------------------

--
-- Estrutura da tabela `mp_contas`
--

CREATE TABLE IF NOT EXISTS `mp_contas` (
  `id` int(11) NOT NULL,
  `user` varchar(24) NOT NULL,
  `novas_mensagens` int(11) NOT NULL,
  `email` varchar(128) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Estrutura da tabela `mp_msgs`
--

CREATE TABLE IF NOT EXISTS `mp_msgs` (
  `id` int(11) NOT NULL,
  `de_contaid` int(11) NOT NULL,
  `para_contaid` int(11) NOT NULL,
  `horario` int(11) NOT NULL,
  `data` varchar(20) NOT NULL,
  `lida` int(11) NOT NULL,
  `Mensagem` varchar(128) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `mp_contas`
--
ALTER TABLE `mp_contas`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `mp_msgs`
--
ALTER TABLE `mp_msgs`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `mp_contas`
--
ALTER TABLE `mp_contas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `mp_msgs`
--
ALTER TABLE `mp_msgs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
